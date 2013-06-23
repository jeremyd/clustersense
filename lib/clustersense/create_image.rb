require 'clustersense'
require 'aws-sdk'

unless ENV['AWS_SECRET_KEY'] && ENV['AWS_ACCESS_KEY']
  say "You must set the environment variables AWS_SECRET_KEY and AWS_ACCESS_KEY."
  exit 1
end
# Ugh aws-sdk likes THESE names.. but ec2tools likes THOSE names.. Set both for now.
ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_ACCESS_KEY']
ENV['AWS_SECRET_ACCESS_KEY'] = ENV['AWS_SECRET_KEY']

ft = HighLine::ColorScheme.new do |cs|
  cs[:headline]        = [ :bold, :yellow, :on_blue ]
  cs[:horizontal_line] = [ :bold, :white ]
  cs[:actions]        = [ :green, :bold, :on_black ]
  cs[:things]         = [ :blue, :bold, :on_black ]
  cs[:urgent]         = [ :black, :bold, :on_red ]
end
HighLine.color_scheme = ft


class AwsMenus
  include Celluloid

  def initialize
    @config = AmiAgents::config(@@config_file)
    @ec2 = AWS::EC2.new()
  end

  def scripts_menu(node_id, chroot=false)
    script_payloads_dir = File.join(AmiAgents::config_dir, "..", "script_payloads")
    available_scripts = Dir.glob(File.join(script_payloads_dir, "*"))
    choose do |menu|
      say "<%= color('Pick a script to execute:', :headline) %>"
      menu.choices(*available_scripts) do |ch|
        say "*** Executing #{ch} on #{node_id} ***"
        if chroot
          if DCell::Node[node_id][:basic].exec_chroot(DCell.me.id, ::IO.read(ch), "/mnt/ebs")
            say "#{ch} ran successfully on #{node_id} in the chroot /mnt/ebs" 
          else
            say "ERROR: #{ch} failed to run in on #{node_id} in the chroot /mnt/ebs"
          end
        else
          if DCell::Node[node_id][:basic].exec(DCell.me.id, ::IO.read(ch))
            say "#{ch} ran successfully on #{node_id}" 
          else
            say "ERROR: #{ch} failed on #{node_id}"
          end
        end
      end
    end
  end

  def imaging_menu
    say "<%= color('Imaging Menu: What would you like to do?', :headline) %>"
    choose do |imaging_menu|
#      imaging_menu.nil_on_handled = true
#      imaging_menu.echo = false
      imaging_menu.readline = true
      imaging_menu.choice("Execute a script on homebase") do
        scripts_menu("homebase")
      end
      imaging_menu.choice("Execute a script on homebase image builder in the EBS filesystem backed chroot.", "exec chroot") do
        scripts_menu("homebase", true)
      end
      imaging_menu.choice("Build brand new Archlinux Cloud Domination AMI.", "build brand new") do
        create_fresh_volume_attach_mount("k", "/mnt/ebs")
        #ec2strap("k", "/mnt/ebs")
      end
      imaging_menu.choice("Create volume from snapshot and attach to homebase.", "create volume from snap") do
        create_volume_from_snap_and_attach
      end
      imaging_menu.choice("Unmount volume detach and delete.", "destroy") do
        umount_volume_detach_delete("k", "/mnt/ebs")
      end
      imaging_menu.choice("Create Archlinux AMI permutation from an EBS volume.", "create ami") do
        create_image_from_volume
      end
    end
  end

  def umount_volume_detach_delete(device_suffix, mount)
    unless homebase.block_device_mappings.include?("/dev/sdk")
      say "/dev/sdk not found in mappings, aborting."
      return false
    end

    unless DCell::Node["homebase"][:basic].exec(DCell.me.id, "umount -l /dev/xvd#{device_suffix}")
      say "umount volume failed (will never happen cause we use -l), continuing anyway.."
    end

    volume_attachment = homebase.block_device_mappings["/dev/sdk"]
    volume = volume_attachment.volume
    volume_attachment.delete(:force => true)
    sleep 1 until volume.status == :available
    volume.delete
  end

  def create_fresh_volume_attach_mount(device_suffix, mount)
    # TODO stub this out, and then take our image building script .. run that on the fresh volume.

    # If a volume is already attached, ask for permission to just use it or bail.
    if homebase.block_device_mappings.include?("/dev/sdk")
      imaging_menu unless agree("There is already a volume attached to /dev/xvdk.  Continue using this volume?")
    else
      # create new volume and attach
      say "Creating new EBS volume.."
      img_vol = @ec2.volumes.create(:size => 20,
                         :availability_zone => homebase.availability_zone)
      say "Attaching volume #{img_vol.id} to target.."
      attachment = img_vol.attach_to(homebase, "/dev/sd#{device_suffix}")
      sleep 1 until attachment.status != :attaching
    end

    # dcell call to homebase to mount it.. nice
    say "Mounting volume.."
    DCell::Node["homebase"][:basic].exec(DCell.me.id, "mkdir -p #{mount}")
    if DCell::Node["homebase"][:basic].exec(DCell.me.id, "mount /dev/xvd#{device_suffix} #{mount}")
      say "mount succeeded"
    else
      say "mount failed!"
      if agree("The mount failed, would you like to format the volume?")
        DCell::Node["homebase"][:basic].exec(DCell.me.id, "mkfs.ext4 /dev/xvd#{device_suffix}")
        DCell::Node["homebase"][:basic].exec(DCell.me.id, "mount /dev/xvd#{device_suffix} #{mount}")
      end
    end
    true
  end

  def ec2strap(devicesuffix, mount)
    image_build_script_file = File.join(AmiAgents::config_dir, "..", "script_payloads", "ec2strap")
    say "Bootstrap AMI using Archlinux install tools"
    DCell::Node["homebase"][:basic].async.exec(DCell.me.id, ::IO.read(image_build_script_file), {"DEST_DIR" => "/mnt/ebs"})
    while(1)
      ask("wanna send some output?") { |answer| DCell::Node["homebase"][:basic].async.push_stdin(answer) }
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

  def create_volume_from_snap_and_attach
    choose do |snap_menu|
      snap_menu.prompt = "Which snapshot should we create volume and attach?"
      snap_menu.choices(*@ec2.snapshots.with_owner("341210305136").collect {|s| [s.description, s.id]}) do |choice|
        @selected_snap = choice[1]
      end
    end

# Create and attach
    say "creating volume from snap #{@selected_snap}"
    home_vol = @ec2.volumes.create(:size => 20,
                       :availability_zone => homebase.availability_zone,
                       :snapshot_id => @selected_snap)
    attachment = home_vol.attach_to(homebase, "/dev/sdk")
    sleep 1 until attachment.status != :attaching
  end

# go make modifications with arch-chroot
  def create_image_from_volume
    @homebase_region = nil
    choose do |region_menu|
      say "<%= color('Which region?', :headline) %>"
      region_menu.choices(*@ec2.regions.map(&:name)) { |reg| @homebase_region = reg }
    end

# choose the volume or autopick
    if(homebase.block_device_mappings.include?("/dev/sdk") && agree("would you like to just use the volume that's attached?"))
      # We know the volume, it's /dev/sdk
      volume_attachment = homebase.block_device_mappings["/dev/sdk"]
      @selected_vol = volume_attachment.volume.id
    else
      choose do |vol_menu|
        vol_menu.prompt = "Which volume should we create the ami from?"
        vol_menu.choices(*@ec2.volumes.collect {|s| [s.create_time,s.id]}) do |choice|
          @selected_vol = choice[1]
        end
      end
    end

    datetimestring=`date +%F-%k%M`
    say "creating new snapshot for volume #{@selected_vol}"
# TODO: create snap instead of menu..
    snapshot = @ec2.snapshots.create(:volume_id => @selected_vol, :description => datetimestring)
    sleep 1 until [:completed, :error].include?(snapshot.status)

# Create Image
    @ec2_homebase = @ec2.regions[@homebase_region]
    ami = @ec2_homebase.images.create(
       :name => "archlinux64-ebs-pv-#{datetimestring}",
       :root_device_name => "/dev/sda1",
       :block_device_mappings => { "/dev/sda1" => { :snapshot_id => snapshot.id, :delete_on_termination => true },
                                   "/dev/sdb" => "ephemeral0" },
       :architecture => "x86_64",
       :kernel_id => "aki-88aa75e1",
       :description => "archlinux created: #{datetimestring}"
       )
    sleep 1 until ami.state == :available
    puts ami.id, ami.description
    say "ami is now available"
  end

  def ping(sender_id, message)
    say message
  end

end

config = AmiAgents::config(@@config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "redis", "host" => config["registry_host"], "port" => 6379 }

AwsMenus.supervise_as :ping
while(1)
  DCell::Node[config["node_id"]][:ping].imaging_menu
end

#image_jockey = AwsMenus.new
#image_jockey.imaging_menu
