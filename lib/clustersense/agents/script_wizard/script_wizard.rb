require 'clustersense'
require 'clustersense/wizards'

class AwsMenus
  include Wizards
  include Celluloid

  def initialize
    @agreements ||= {}
  end

  def main_menu()
    question = "Execute on APP servers."
    scripts_menu_choices = {
      "Execute a script on all app servers" => 
          ->(response){ scripts_menu("app1") },
      }
    choices(question, scripts_menu_choices.keys, true) do |choice|
      scripts_menu_choices[choice].call(choice)
    end
  end

  def scripts_menu(node_id)
    script_payloads_dir = File.join(Clustersense::config_dir, "..", "script_payloads")
    available_scripts = Dir.glob(File.join(script_payloads_dir, "*")).collect {|c| File.basename(c)}
    choices("Pick a script from your war chest.", available_scripts) do |choice|
      userlog "*** Preparing to execute#{choice} ***"
      all_app_nodes = DCell::Node.all.select do |n| 
        n.id =~ /^app/ 
      end
      all_apps = all_app_nodes.collect { |c| c.id }
      agree("Are you SURE you want to execute:<br> <b>#{choice}</b> on #{all_apps.size} APP servers: #{all_apps.join(",")}") do |answer|
        if answer =~ /yes/
          all_apps.each do |app_server|
            if DCell::Node[app_server][:basic].exec(DCell.me.id.to_s, ::IO.read(File.join(script_payloads_dir,choice)).to_s)
              userlog "#{app_server}: Execution completed successfully." 
            else
              userlog "#{app_server}: Execution failed!"
            end
          end
        else
          userlog "Aborting due to user intervention"
        end
      end 
# back to imaging
    main_menu
    end 
  end
end

config_file = @trollop_options[:config]
config = Clustersense::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "zk", "servers" => [config["registry_host"]], "port" => 2181 }

AwsMenus.supervise_as :ping

DCell::Node[config["node_id"]][:ping].main_menu
