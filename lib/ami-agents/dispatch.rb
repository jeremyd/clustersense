require 'ami-agents'
require 'ami-agents/helpers/easyrsa'
require 'aws-sdk'
require 'fileutils'
require 'pry'

unless ENV['AWS_SECRET_KEY'] && ENV['AWS_ACCESS_KEY']
  say "You must set the environment variables AWS_SECRET_KEY and AWS_ACCESS_KEY."
  exit 1
end
unless ENV['EASY_RSA']
  say "You must set the environment variable EASY_RSA to the root of your easy-rsa path."
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

class Dispatch
  include Celluloid

  def show_message(message)
    say(message)
    return true
  end
end

class DispatchBootstrap
# wait for an ip address to be pingable
# used for detecting openvpn network availability
  def wait_for_ping(ip)
    ping_cmd = "ping -W 5 -c 1 #{ip}"
    puts `#{ping_cmd}`
    timeout = 0
    while($?.success? == false) do
      sleep 2
      timeout += 2
      puts "waited #{timeout}s for #{ip} to be pingable.."

      if timeout >= 120
        puts "error: timed out waiting for ip: #{ip} to be pingable."
        return false
      end
      puts `#{ping_cmd}`
    end
    true
  end

# waiting for public_dns from the ec2 api so we know where the openvpn server is.
  def wait_for_public_dns_name(ec2_server)
    timeout = 0
    while(ec2_server.public_dns_name == nil)
      sleep 5
      timeout += 5
      puts "waited #{timeout}s for #{ec2_server} to have a public_dns_name.."
      if timeout >= 120
        puts "error: timed out waiting for public_dns for #{ec2_server}."
        return false
      end
    end
    ec2_server.public_dns_name
  end

  def initialize(config_file)
    config = AmiAgents::config(config_file)
    ec2 = AWS::EC2.new()
    if config["homebase_region"]
      @homebase_region = config["homebase_region"]
    else
      choose do |region_menu|
        region_menu.header = "<%= color('Which region is homebase?', :bold) %>"
        say "<%= color('Which region is your homebase?', :headline) %>"
        region_menu.choices(*ec2.regions.map(&:name)) { |reg| @homebase_region = reg }
      end
    end
    say "Using homebase region #{@homebase_region}."
    ec2_homebase = ec2.regions[@homebase_region]
# See if homebase is already running based on tag search
    homebase_sel = ec2.instances.select { |i| i if i.tags.include?("homebase") && [:running, :pending].include?(i.status) }
    homebase = nil
    if homebase_sel.empty?
      say "Detected Homebase was not running"
      say "Generating user-data for homebase OpenVPN"
      write_userdata_cmd = "#{WRITE_MIME} --output #{USER_DATA_TMP} #{USER_DATA_SCRIPTS}/part-handler.py:text/part-handler" 
      secrets = %w[ca.crt server.crt server.key dh1024.pem ta.key]
      secrets.each do |sec|
        write_userdata_cmd += " #{ENV['EASY_RSA']}/keys/#{sec}:text/openvpn-secret"
      end
      write_userdata_cmd += " #{ENV['EASY_RSA']}/server.conf:text/openvpn-conf"
      write_userdata_cmd += " #{USER_DATA_SCRIPTS}/redis.conf:text/redis-conf"
      write_userdata_cmd += " #{USER_DATA_SCRIPTS}/start_openvpn.sh"
      puts "running #{write_userdata_cmd}"
      puts `#{write_userdata_cmd} 2>&1`
      raise "fatal:could not write userdata" unless $?.success?
      say "Finding Archlinux Cloud World Domination Image in #{@homebase_region}"
      # Uncomment for uplink labs
      #archlinux_images = ec2_homebase.images.with_owner("460511294004")
      #select_ami = archlinux_images.select {|s| s.name =~ /pv.+2012.11.22.+x86_64.+ebs/}.first
      # For jeremy's images
      archlinux_images = ec2_homebase.images.with_owner("341210305136")
      # last known awesome
      #select_ami = archlinux_images.select {|s| s.name =~ /2013-03-22-2159/}.first
      # new uplink integration
      select_ami = archlinux_images.select {|s| s.name =~ /2013-03-23- 401/}.first
      Trollop::die "FATAL: could not locate archlinux cloud world domination ami!" unless select_ami

      say "Launching Homebase."
      homebase = select_ami.run_instance(:security_groups => [ "default" ], 
                                         :availability_zone => "us-east-1c",
                                         :instance_type => "t1.micro",
                                         :key_name => "jeremy_default",
                                         :user_data => IO.read(USER_DATA_TMP))

# why would this fail with aws-instance-id non-exist? sheesh..
      sleep 1

      homebase.tag("homebase", :value => "true")
    else
      say "Homebase already running."
      homebase = homebase_sel.first
    end

    if(pub_dns = wait_for_public_dns_name(homebase))
      say "Starting connection to OpenVPN network"
    else
# If public_dns times out we need to just exit. (Should not happen)
      exit(1)
    end

    dispatch_ovpn = OvpnClient.new({:ca => "#{ENV['EASY_RSA']}/keys/ca.crt",
                   :cert => "#{ENV['EASY_RSA']}/keys/meatwad.crt",
                   :key => "#{ENV['EASY_RSA']}/keys/meatwad.key",
                   :tls_auth => "#{ENV['EASY_RSA']}/keys/ta.key",
                   :serverip => pub_dns })

    dispatch_ovpn.config
    dispatch_ovpn.cycle

    say "OpenVPN client restarted.  Waiting for OpenVPN server to respond."

    if(wait_for_ping("10.8.0.1"))
      say "OpenVPN connection success.  Connecting to DCell network"
    else
# If ping times out we need to just exit. (Should not happen)
      exit(1)
    end
  end

end

config_file = @trollop_options[:config]
DispatchBootstrap.new(config_file)
config = AmiAgents::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "redis", "host" => config["registry_host"], "port" => 6379 }

Dispatch.supervise_as :dispatch

say "DCell network is online.  Dispatch connected."

def main_menu
  node_list_menu
  #choose do |menu|
  #  menu.header = "Main Menu"
  #  menu.choice "Node List" do
  #    node_list_menu
  #  end
  #end
end

def actors_menu(node_id)
  choose do |menu|
    say "<%= color(\"Available Agents on '#{node_id}':\", :headline) %>"
    known_actors_list = [:basic, :info]
    get_known_actors = DCell::Node[node_id].actors.select { |c| 
      c if known_actors_list.include?(c)
    }
    get_known_actors.each do |a|
      menu.prompt = "? "
      if known_actors_list.include?(a)
        highlight_choice = HighLine.color(a.to_s, :things)
      else
        highlight_choice = a.to_s
      end
      menu.choice(highlight_choice) do
        @selected_actor = DCell::Node[node_id][a]
        if a == :basic
          basic_cell_menu(node_id)
        elsif a == :info
          say "Node Info for #{node_id}:"
          say "  hostname: #{DCell::Node[node_id][a].hostname}"
          say "  uptime: #{DCell::Node[node_id][a].uptime}"
          say "  load_average: #{DCell::Node[node_id][a].load_average}"
          say "  os_version: #{DCell::Node[node_id][a].os_version}"
          say "  platform: #{DCell::Node[node_id][a].platform}"
          say "  distribution: #{DCell::Node[node_id][a].distribution}"
          say "  cpu_arch: #{DCell::Node[node_id][a].cpu_arch}"
          say "  cpu_count: #{DCell::Node[node_id][a].cpu_count}"
          say "  cpu_speed: #{DCell::Node[node_id][a].cpu_speed}"
          say "  ruby_version: #{DCell::Node[node_id][a].ruby_version}"
          say "  ruby_engine: #{DCell::Node[node_id][a].ruby_engine}"
          say "  ruby_platform: #{DCell::Node[node_id][a].ruby_platform}"
          binding.pry
        else
          say "you picked an actor I don't recognize, dropping to pry shell for working with @selected_actor"
          binding.pry
        end
        main_menu
      end
    end
  end
end

def basic_cell_menu(node_id)
  choose do |menu|
    say "<%= color('Basic cell actions for #{node_id}:', :headline) %>"
    menu.choice(HighLine.color("ssh - ssh to the node", :actions)) do
      say("you could ssh there! ssh #{DCell::Node[node_id][:basic].ip_address}")
      basic_cell_menu(node_id)
    end

    menu.choice(HighLine.color("infect - upload and exec new gem code", :actions)) do
      # just give it a url, and jockey reelweb/apache to send it
      DCell::Node[node_id][:basic].infect!("http://10.8.0.6:8090/ami-agents-0.0.1.gem")
      say(HighLine.color("success: node infected!", :urgent))
      basic_cell_menu(node_id)
    end

    menu.choice(HighLine.color("exec(script_string) - This executes the payload on the target node.", :actions)) do
      unless ENV['SCRIPTS']
        say "you must set the environment variable scripts to your scripts directory"
        basic_cell_menu(node_id)
      else
        scripts_menu(node_id)
      end
    end
    menu.choice(HighLine.color("exec_chroot(script_string, chroot_dir) - This executes the payload on the target node IN A CHROOT.", :actions)) do
      unless ENV['SCRIPTS']
        say "you must set the environment variable scripts to your scripts directory"
        exit 1
      else
        scripts_chroot_menu(node_id)
      end
    end
    menu.choice(HighLine.color("Back to Main Menu", :actions)) { main_menu }
  end
end

def scripts_chroot_menu(node_id)
  available_scripts = Dir.glob(File.join(ENV['SCRIPTS'], "*"))
  choose do |menu|
    say "<%= color('Pick a script to execute IN THE CHROOT:', :headline) %>"
    menu.choices(*available_scripts) do |ch|
      say "*** Executing #{ch} on #{node_id} ***"
      if DCell::Node[node_id][:basic].exec_chroot(IO.read(ch), "/mnt/ebs")
        say "#{ch} ran successfully on #{node_id}" 
      else
        say "ERROR: #{ch} failed on #{node_id}"
      end
      basic_cell_menu(node_id)
    end
  end
end

def scripts_menu(node_id)
  available_scripts = Dir.glob(File.join(ENV['SCRIPTS'], "*"))
  choose do |menu|
    say "<%= color('Pick a script to execute:', :headline) %>"
    menu.choices(*available_scripts) do |ch|
      say "*** Executing #{ch} on #{node_id} ***"
      if DCell::Node[node_id][:basic].exec(IO.read(ch))
        say "#{ch} ran successfully on #{node_id}" 
      else
        say "ERROR: #{ch} failed on #{node_id}"
      end
      basic_cell_menu(node_id)
    end
  end
end

def node_list_menu
  choose do |menu|
    say "<%= color('Node List:', :headline) %>"
    nodes = DCell::Node.all.map{|m| m.id}
    nodes.each do |node|
      menu.choice(HighLine.color(node, :things)) { actors_menu(node) }
    end
  end
end

main_menu

sleep
