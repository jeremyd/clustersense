require 'clustersense'
require 'clustersense/helpers/wizards'
require 'aws-sdk'

unless ENV['AWS_SECRET_KEY'] && ENV['AWS_ACCESS_KEY']
  say "You must set the environment variables AWS_SECRET_KEY and AWS_ACCESS_KEY."
  exit 1
end
# Ugh aws-sdk likes THESE names.. but ec2tools likes THOSE names.. Set both for now.
ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_ACCESS_KEY']
ENV['AWS_SECRET_ACCESS_KEY'] = ENV['AWS_SECRET_KEY']

class AwsMenus
  include Wizards
  include Celluloid

  def initialize
    @ec2 = AWS::EC2.new()
# agreements is for wizards, todo move this or whatever
    @agreements ||= {}
  end

 # move this to a test?
  def imaging_menu_sample
    agree("You don't need to GO to cluster sense, cluster sense comes to you.") do |result|
      if result =~ /yes/
        choices("hi world", ["you", "said", "yes", "red", "blue", "too"]) do |other_result| 
          userlog other_result 
          if other_result =~ /blue/
            agree("YOU GOT LUCKY?! YOU PICKED BLUE?! , right?") {|result| userlog result }
          end
        end
      else
        userlog "NO"
        agree("you said no, agreed?") { |other_response| userlog other_response }
      end
    end
  end

  def imaging_menu
    question = "Imaging Menu: What would you like to do?"
    imaging_menu_choices = {
      "Execute a script on the master server." => 
          ->(response){ scripts_menu("homebase") },

      "Execute a script on image builder server in the EBS backed chroot." => 
          ->(response){ scripts_menu("homebase", true) },
          
      "Build brand new Archlinux Cloud Domination AMI (from scratch)." => 
          ->(response){ create_fresh_volume_attach_mount("k", "/mnt/ebs") },

      "Create Volume from snapshot and attach to homebase." =>
          ->(response){ create_volume_from_snap_and_attach("k", "/mnt/ebs") },

      "Umount currently attached EBS volume, detach and DELETE." =>
          ->(response){ umount_volume_detach_delete("k", "/mnt/ebs") },
          
      "Create Archlinux AMI permutation from an EBS volume." =>
          ->(response){ create_image_from_volume }
      }
    choices(question, imaging_menu_choices.keys, true) do |choice|
      imaging_menu_choices[choice].call(choice)
    end
  end

  def homebase
    homebase_sel = @ec2.instances.select { |i| i if i.tags.include?("homebase") && [:running, :pending].include?(i.status) }
    if homebase_sel.empty?
      say "Homebase not running, unable to continue."
      exit 1
    end
    homebase = homebase_sel.first
  end

  def scripts_menu(node_id, chroot=false)
    script_payloads_dir = File.join(AmiAgents::config_dir, "..", "script_payloads")
    available_scripts = Dir.glob(File.join(script_payloads_dir, "*"))
    choices("Pick a script from your war chest.", available_scripts) do |choice|
      userlog "*** Executing #{choice} on #{node_id} ***"
      if chroot
        if DCell::Node[node_id][:basic].exec_chroot(DCell.me.id, ::IO.read(choice), "/mnt/ebs")
          userlog "#{choice} ran successfully on #{node_id} in the chroot /mnt/ebs" 
        else
          userlog "ERROR: #{choice} failed to run in on #{node_id} in the chroot /mnt/ebs"
        end
      else
        if DCell::Node[node_id][:basic].exec(DCell.me.id, ::IO.read(choice), "AWS_ACCESS_KEY" => ENV["AWS_ACCESS_KEY"], "AWS_SECRET_KEY" => ENV["AWS_SECRET_KEY"])
          userlog "#{choice} ran successfully on #{node_id}" 
        else
          userlog "ERROR: #{choice} failed on #{node_id}"
        end
      end
# back to imaging
      imaging_menu
    end 
  end

  def umount_volume_detach_delete(device_suffix, mount)
    unless homebase.block_device_mappings.include?("/dev/sdk")
      userlog "/dev/sdk not found in mappings, aborting."
      imaging_menu
      return false
    end

    unless DCell::Node["homebase"][:basic].exec(DCell.me.id, "umount -l /dev/xvd#{device_suffix}")
      userlog "umount volume failed (will never happen cause we use -l), continuing anyway.."
    end

    volume_attachment = homebase.block_device_mappings["/dev/sdk"]
    volume = volume_attachment.volume
    volume_attachment.delete(:force => true)
    userlog "waiting for #{volume.id} to be detached for deletion."
    sleep 1 until volume.status == :available
    volume.delete
    userlog "volume #{volume.id} deleted."
    imaging_menu
  end

  def create_volume_from_snap_and_attach(device_suffix, mount)
    snap_choices = {}
    @ec2.snapshots.with_owner("341210305136").each {|s| snap_choices[s.description.chomp] = s.id }
    choices("Which snapshot should we create the volume and attach from?", snap_choices.keys) do |choice|
      @selected_snap = snap_choices[choice]
      userlog @selected_snap
# Create and attach
      userlog "creating volume from snap #{@selected_snap}"
      home_vol = @ec2.volumes.create(:size => 20,
                         :availability_zone => homebase.availability_zone,
                         :snapshot_id => @selected_snap)
      attachment = home_vol.attach_to(homebase, "/dev/sdk")
      sleep 1 until attachment.status != :attaching
      # dcell call to homebase to mount it.. nice
      userlog "Mounting volume.."
      DCell::Node["homebase"][:basic].exec(DCell.me.id, "mkdir -p #{mount}")
      if DCell::Node["homebase"][:basic].exec(DCell.me.id, "mount /dev/xvd#{device_suffix} #{mount}")
        userlog "mount succeeded!"
      else
        userlog "mount failed!"
      end
      imaging_menu
    end
  end

  def create_fresh_volume_attach_mount(device_suffix, mount)
    # If a volume is already attached, ask for permission to just use it or bail.
    if homebase.block_device_mappings.include?("/dev/sdk")
      agree("There is already a volume attached to /dev/xvdk.  Continue using this volume?") do |yn|
        unless yn
          # bail
          return
        end
      end
    end
    # create new volume and attach
    userlog "Creating new EBS volume.."
    img_vol = @ec2.volumes.create(:size => 20,
                       :availability_zone => homebase.availability_zone)
    userlog "Attaching volume #{img_vol.id} to target.."
    attachment = img_vol.attach_to(homebase, "/dev/sd#{device_suffix}")
    sleep 1 until attachment.status != :attaching

    # dcell call to homebase to mount it.. nice
    userlog "Mounting volume.."
    DCell::Node["homebase"][:basic].exec(DCell.me.id, "mkdir -p #{mount}")
    if DCell::Node["homebase"][:basic].exec(DCell.me.id, "mount /dev/xvd#{device_suffix} #{mount}")
      userlog "mount succeeded"
    else
      userlog "mount failed!"
      agree("The mount failed, would you like to format the volume?") do |yn|
        if yn
          DCell::Node["homebase"][:basic].exec(DCell.me.id, "mkfs.ext4 /dev/xvd#{device_suffix}")
        end
      end
    end
    imaging_menu
    true
  end

  def create_image_from_volume
    # TODO: how to get the region?
    @homebase_region = homebase.availability_zone
    puts "using region #{@homebase_region}"
# choose the volume or autopick
    if(homebase.block_device_mappings.include?("/dev/sdk"))
      agree("would you like to just use the volume that's attached?") do |yn|
        if yn
          # We know the volume, it's /dev/sdk
          volume_attachment = homebase.block_device_mappings["/dev/sdk"]
          @selected_vol = volume_attachment.volume.id
          userlog "Using #{@selected_vol} that was already attached to /dev/xvdk for AMI creation."
          create_ami(@selected_vol, "us-east-1")
        else
          userlog "Aborting: need to detach the volume if you want to continue."
          imaging_menu
          return
        end
      end
    else
      volume_map = {}
      @ec2.volumes.each { |s| volume_map[s.create_time] = s.id }
      choices("Which volume (by creation time) to use?", volume_map.keys) do |choice|
        @selected_vol = volume_map[choice]
        create_ami(@selected_vol, "us-east-1")
      end
    end
  end

  def create_ami(selected_vol, region)
    datetimestring=`date +%F-%k%M`
    userlog "creating new snapshot for volume #{@selected_vol}"
    snapshot = @ec2.snapshots.create(:volume_id => @selected_vol, :description => datetimestring)
    sleep 1 until [:completed, :error].include?(snapshot.status)

# Create Image
    ec2_homebase = @ec2.regions[region]
    ami = ec2_homebase.images.create(
       :name => "archlinux64-ebs-pv-#{datetimestring}",
       :root_device_name => "/dev/sda1",
       :block_device_mappings => { "/dev/sda1" => { :snapshot_id => snapshot.id, :delete_on_termination => true },
                                   "/dev/sdb" => "ephemeral0" },
       :architecture => "x86_64",
       :kernel_id => "aki-88aa75e1",
       :description => "archlinux created: #{datetimestring}"
       )
    sleep 1 until ami.state == :available
    userlog "#{ami.id}, #{ami.description}"
    userlog "ami is now available!"
    imaging_menu
  end
end

config_file = @trollop_options[:config]
config = AmiAgents::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "redis", "host" => config["registry_host"], "port" => 6379 }

AwsMenus.supervise_as :ping

DCell::Node[config["node_id"]][:ping].imaging_menu
