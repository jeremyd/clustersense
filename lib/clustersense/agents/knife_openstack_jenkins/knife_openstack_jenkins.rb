require 'clustersense/agents'
require 'clustersense/wizards'
require 'clustersense/agents/knife_common/knife_agent'
require 'json'

class KnifeOpenstackJenkins
  include Wizards
  include Celluloid
  include KnifeAgent

  # environmental inputs:
  # ACTION
  # COOKBOOK_NAME
  # BASIC AGENT TARGET (node name)
  # TAG (build number? + cookbookname/uniquething)

  # needs to:
  # launch_cluster, berks refresh+merge environments, cleanup, run_chef
  def initialize
    @job_tracker ||= {}
  end

  #MAIN
  def run_job
    unless ENV['COOKBOOK_DIR']
      userlog "Aborting. The environment variable $COOKBOOK_DIR must be set."
      exit 1
    end

    unless ENV['COOKBOOK_NAME']
      userlog "Aborting. The environment variable $COOKBOOK_NAME must be set."
      exit 1
    end

    unless ENV['MYTAG']
      userlog "Aborting. The environment variable $COOKBOOK_NAME must be set."
      exit 1
    end

    unless ENV['CLUSTER_SIZE']
      userlog "Using $CLUSTER_SIZE=3 (default)."
      ENV['CLUSTER_SIZE'] = "3"
    end

    @cluster_name = "#{ENV['COOKBOOK_NAME']}-#{ENV['MYTAG']}-0"

    case ENV['ACTION']
      when nil
        userlog "Aborting. The environment variable $ACTION must be set."
        exit 1
      when "launch_cluster"
        launch_cluster(ENV['COOKBOOK_NAME'], ENV['CLUSTER_SIZE'].to_i)
      when "berks_refresh"
        berks_refresh(ENV['COOKBOOK_NAME'])
        write_environment
      when "run_chef"
        run_chef(ENV['COOKBOOK_NAME'])
      when "cleanup"
        delete_if_exists(@cluster_name)
    end

# wait for jobs to finish
    after(1) do
      every(1) do
        if check_jobs_complete
          userlog "ALL JOBS FINISHED. EXITING."
          after(1) do 
            if all_successful?
              exit 0 
            else
              exit 1
            end
          end 
        end
      end
    end
  end

  def write_environment(node="app2")
    cookbook_path = File.join(ENV['COOKBOOK_DIR'], ENV['COOKBOOK_NAME'])
    target_env_file = File.join(cookbook_path, "environments", "mytag.json")
    modified_name = "#{ENV['COOKBOOK_NAME']}-#{ENV['MYTAG']}"
    modified_env = mod_environment(cookbook_path, "stage.json", modified_name)
    ::IO.write(target_env_file, modified_env)
    # perform the upload
    payload =<<EOF
      #!/bin/bash -e --login
      echo knife environment from file #{target_env_file}
      knife environment from file #{target_env_file}
EOF
    DCell::Node[node][:basic].exec(DCell.me.id, payload, {}, track_job)
  end

  def ping(sender_id, message)
    puts("#{message} from #{sender_id}")
    userlog("#{sender_id}: #{message}")
  end

end

config_file = @trollop_options[:config]
config = Clustersense::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "zk", "servers" => [config["registry_host"]], "port" => 2181 }

KnifeOpenstackJenkins.supervise_as :ping

DCell::Node[config["node_id"]][:ping].run_job
