require 'clustersense'
require 'clustersense/helpers/wizards'
require 'clustersense/helpers/easyrsa'
require 'aws-sdk'

unless ENV['AWS_SECRET_KEY'] && ENV['AWS_ACCESS_KEY']
  say "You must set the environment variables AWS_SECRET_KEY and AWS_ACCESS_KEY."
  exit 1
end
unless ENV['EASY_RSA']
  say "You must set the environment variable EASY_RSA."
  exit 1
end

# Ugh aws-sdk likes THESE names.. but ec2tools likes THOSE names.. Set both for now.
ENV['AWS_ACCESS_KEY_ID'] = ENV['AWS_ACCESS_KEY']
ENV['AWS_SECRET_ACCESS_KEY'] = ENV['AWS_SECRET_KEY']

#
## This is a plugin that assists with launching Ec2 servers and associated OpenVPN credentials.
#

class Ec2Gun
  include Wizards
  include Celluloid

  def initialize
    @ec2 = AWS::EC2.new()
# agreements is for wizards, todo move this or whatever
    @agreements ||= {}
    @easyrsa = EasyRSA.new(ENV['EASY_RSA'])
  end

  def ec2_gun_menu
    ec2gun_menu = {
      "List all OpenVPN slots in the store." =>
        ->(){ choices("List all OpenVPN keys.", @easyrsa.list_keys) {|choice| userlog choice; ec2_gun_menu } },
      "Create new slot." =>
        ->(){ ask("slotname?") {|answer| create_slot(answer) }; ec2_gun_menu }
    }
    choices("Manage your Ec2 ammo with Ec2gun", ec2gun_menu.keys, true) do |choice|
      ec2gun_menu[choice].call
    end
  end

  def create_slot(name)
    userlog @easyrsa.gen_client_key(name)
  end
end

config_file = @trollop_options[:config]
config = AmiAgents::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "redis", "host" => config["registry_host"], "port" => 6379 }

Ec2Gun.supervise_as :ping

DCell::Node[config["node_id"]][:ping].ec2_gun_menu
