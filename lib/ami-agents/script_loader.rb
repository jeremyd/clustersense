require 'ami-agents'
require 'ami-agents/easyrsa'
require 'aws-sdk'
require 'fileutils'

unless ENV['SCRIPTS']
  say "WARNING: environment variable SCRIPTS not set to a directory.  Executing scripts not available."
end

class ScriptLoader
  def self.send_payload_list(list)
    if DCell::Node["reelweb"] && DCell::Node["reelweb"][:time_server]
      DCell::Node["reelweb"][:time_server].set_payload_list(list)
      return true
    else
      return false
    end
  end
end

config = AmiAgents::config(@@config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "redis", "host" => config["registry_host"], "port" => 6379 }

ScriptLoader.supervise_as :script_dispatch
available_scripts = Dir.glob(File.join(ENV['SCRIPTS'], "*"))
ScriptLoader.send_payload_list(available_scripts)
