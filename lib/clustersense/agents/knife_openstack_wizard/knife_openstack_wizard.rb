require 'clustersense/agents'
require 'clustersense/agents/knife_common/knife_agent'
require 'clustersense/wizards'
require 'json'

class AwsMenus
  include Wizards
  include Celluloid
  include KnifeAgent

  def initialize
    @agreements ||= {}
    @job_track ||= {}
  end

  def main_menu()
    question = "Knife Openstack"
    menu_choices = {
      "Berks Menu" => 
          ->(response){ berks_refresh_menu() },
      "Run Chef" => 
          ->(response){ run_chef_menu() },
      "Launch Cluster" => 
          ->(response){ launch_cluster_menu() },
      "Terminate Cluster" => 
          ->(response){ terminate_cluster_menu() },
      "Unload Wizard" =>
          ->(response){ after(3) { exit(0) } }
      }
    choices(question, menu_choices.keys, true) do |choice|
      menu_choices[choice].call(choice)
    end
  end

  # receives a cookbook name to operate on
  def berks_sub_menu(cookbook_name)
    question = "Which Berks?"
    menu_choices = {
      "Upload Dynamic Environment" => 
          ->(response){ ask_about_environment(cookbook_name) },
      "Berks Install" => 
          ->(response){ berks_install(cookbook_name) },
      "Berks Update" => 
          ->(response){ berks_update(cookbook_name) },
      "Berks Upload" => 
          ->(response){ berks_upload(cookbook_name) },
      "ALL" =>
          ->(response){ berks_refresh(cookbook_name) },
      "back" =>
          ->(response){ main_menu }
      }
    choices(question, menu_choices.keys, false) do |choice|
      menu_choices[choice].call(choice)
    end
  end

  # Provide user a list of cookbooks in COOKBOOK_DIR to upload with berks.
  def terminate_cluster_menu()
    question = "Launch a cluster"
    unless ENV['COOKBOOK_DIR']
      agree("Aborting.  You must set the environment variable COOKBOOK_DIR.  Would you like to exit the wizard?") do |answer|
        if answer =~ /yes/i
          after(3) { exit 0 } if answer =~ /yes/i
        else
          main_menu
        end
      end
    else
      menu_choices = {}
      cookbook_dirs = Dir.glob(File.join(ENV['COOKBOOK_DIR'], "*")).select {|s| File.directory?(s) }
      cookbook_dirs.each do |d|
        x = File.basename(d)
        cluster_name = "#{x}-#{ENV['mytag']}-0"
        menu_choices[x] = ->(response){ delete_if_exists(x) }
      end
      choices(question, menu_choices.keys, false) do |choice|
        menu_choices[choice].call(choice)
      end
      main_menu
    end
  end

  # Provide user a list of cookbooks in COOKBOOK_DIR to upload with berks.
  def launch_cluster_menu()
    question = "Launch a cluster"
    unless ENV['COOKBOOK_DIR']
      agree("Aborting.  You must set the environment variable COOKBOOK_DIR.  Would you like to exit the wizard?") do |answer|
        if answer =~ /yes/i
          after(3) { exit 0 } if answer =~ /yes/i
        else
          main_menu
        end
      end
    else
      menu_choices = {}
      cookbook_dirs = Dir.glob(File.join(ENV['COOKBOOK_DIR'], "*")).select {|s| File.directory?(s) }
      cookbook_dirs.each do |d|
        x = File.basename(d)
        menu_choices[x] = ->(response){ launch_cluster(x, 3) }
      end
      choices(question, menu_choices.keys, false) do |choice|
        menu_choices[choice].call(choice)
      end
      main_menu
    end
  end

  # Provide user a list of cookbooks in COOKBOOK_DIR to upload with berks.
  def berks_refresh_menu()
    question = "Refresh which cookbook?"
    unless ENV['COOKBOOK_DIR']
      agree("Aborting.  You must set the environment variable COOKBOOK_DIR.  Would you like to exit the wizard?") do |answer|
        if answer =~ /yes/i
          after(3) { exit 0 } if answer =~ /yes/i
        else
          main_menu
        end
      end
    else
      menu_choices = {}
      cookbook_dirs = Dir.glob(File.join(ENV['COOKBOOK_DIR'], "*")).select {|s| File.directory?(s) }
      cookbook_dirs.each do |d|
        x = File.basename(d)
        menu_choices[x] = ->(response){ berks_sub_menu(x); }
      end
      choices(question, menu_choices.keys, false) do |choice|
        menu_choices[choice].call(choice)
      end
    end
  end

  def ask_about_environment(cookbook_name, node="app2")
    cookbook_path = File.join(ENV['COOKBOOK_DIR'], cookbook_name)
    target_env_file = File.join(cookbook_path, "environments", "mytag.json")
    question = "Would you like to run with the default environment?"
    userlog("target env file is #{target_env_file}")
    agree(question) do |answer|
      if answer =~ /yes/i
# knife upload the default, launch with the default, modify the name though
        ::IO.write(target_env_file, mod_environment(cookbook_path, "stage.json", "#{cookbook_name}-#{ENV['mytag']}"))
      else
# knife upload a dynamically generated environment with modified name and launch
# TODO: actually override more options? Right now overriding tagname might be good enough..
        ::IO.write(target_env_file, mod_environment(cookbook_path, "stage.json", "#{cookbook_name}-#{ENV['mytag']}"))
      end

# perform the upload
      payload =<<EOF
        #!/bin/bash -e --login
        echo knife environment from file #{target_env_file}
        knife environment from file #{target_env_file}
EOF
      after(3) { DCell::Node[node][:basic].exec(DCell.me.id, payload) }
    end
    main_menu
  end

  def give_chef
    # Uhh, can't use knife openstack here duh, cause that needs a chef server (CHICKEN MEET EGG)
    #knife openstack image list |grep -i chef-server-11|cut -f1 -d " "
    image_id = "bec9d5ba-d61b-4e67-9dd5-2134e758ede9" # os0 chef-server-11 
    my_chef = "chef-server-11-#{ENV['mytag']}"
    tenant_name = "stage"
    payload =<<EOF 
        #knife openstack server create --environment #{environment_name} -f 2 -I #{image_id} --node-name #{my_chef} -S #{tenant_name} -i ~/stage.pem --no-host-key-verify -x ubuntu --nics '[{ \"net_id\": \"df18aba9-7daf-41fe-bb2a-82c586a686fc\" }]' --bootstrap-network vlan2020
EOF
    DCell::Node[node][:basic].async.exec(DCell.me.id, payload)
  end

  def run_chef_menu
    question = "Run chef-client on which cluster?"
    cookbook_dirs = Dir.glob(File.join(ENV['COOKBOOK_DIR'], "*")).select {|s| File.directory?(s) }
    menu_choices = {}
    cookbook_dirs.each do |d|
      x = File.basename(d)
      menu_choices[x] = ->(response){ run_chef(x); }
    end
    choices(question, menu_choices.keys, false) do |choice|
      menu_choices[choice].call(choice)
    end
  end
end

config_file = @trollop_options[:config]
config = Clustersense::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "zk", "servers" => [config["registry_host"]], "port" => 2181 }

AwsMenus.supervise_as :ping

DCell::Node[config["node_id"]][:ping].main_menu
