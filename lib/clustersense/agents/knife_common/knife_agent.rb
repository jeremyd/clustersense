module KnifeAgent

  # overrides at runtime the environment settings and name for this cluster.
  def mod_environment(cookbook_path, env_template_name, modified_name, option_mods={})
    raw = ::IO.read(File.join(cookbook_path, "environments", env_template_name))
    mod_this = JSON::parse(raw)
    mod_this['name'] = modified_name
    return mod_this.merge(option_mods).to_json
  end

  def knife_bin
    "/var/lib/clustersense/rubies/ruby-2.0.0/bin/knife"
  end

  def delete_if_exists(name, node="app2")
    payload =<<EOF 
#!/bin/bash -x 
      declare -a serverid
      serverid=(
        $(#{knife_bin} openstack server list |grep #{name}|cut -f1 -d " ")
        )
      
      for i in "${serverid[@]}"; do
        if [ "$i" ]; then
          #{knife_bin} openstack server delete $i --purge --yes
        fi
      done

      declare -a clientid
      clientid=(
        $(#{knife_bin} client list |grep #{name})
        )

      for i in "${clientid[@]}"; do
        if [ "$i" ]; then
          #{knife_bin} client delete $i --yes
        fi
      done
EOF
    DCell::Node[node][:basic].exec(DCell.me.id, payload, @ko_opts, track_job)
    true
  end

  def track_job
    @job_tracker ||= {}
    this_id = `uuidgen`.strip
    @job_tracker[this_id] = { 'running' => true, 'exitstatus' => nil }
    this_id
  end

  def check_jobs_complete
    still_running = []
    @job_tracker.keys.each do |key|
      still_running << key if @job_tracker[key]['running']
    end
    return true if still_running.size == 0
    return false
  end

  def run_chef(cookbook_name, node="app2")
    environment_name = "#{cookbook_name}-#{ENV['MYTAG']}"
    cluster_name = "#{cookbook_name}-#{ENV['MYTAG']}-0"
    userlog("**cluster_name is #{cluster_name}")
    payload =<<EOF 
#!/bin/bash -e
      #{knife_bin} ssh "name:#{cluster_name}*" "sudo chef-client --environment #{environment_name}" -i /home/ubuntu/workspace/chef/.chef/p_and_i.pem -a ipaddress --no-host-key-verify -x ubuntu
EOF
    DCell::Node[node][:basic].async.exec(DCell.me.id, payload, @ko_opts, track_job)
    true
  end

  def launch_storm(cookbook_name, cluster_size=1, node="app2")
    #image_id = "02b5d86b-7d8f-4b51-a191-9a0a15596ea6" # Precise 12.04
    image_id = "caa89f87-cae1-4354-960f-793913800aab" # service-image-38-stage , not sure why we use this.. but ZK isn't doing apt-get update.. grr 
    working_dir = File.join(ENV['COOKBOOK_DIR'], cookbook_name)
    environment_name = "#{cookbook_name}-#{ENV['MYTAG']}"
    tenant_name = "p_and_i"
    cluster_name = "#{cookbook_name}-#{ENV['MYTAG']}-0"

    delete_if_exists(cluster_name)

    runlist = ""
    cluster_size.times do |cid|
      if cid == 0
        runlist = "recipe[#{cookbook_name}::deploy],recipe[storm::nimbus],recipe[storm::ui]"
      elsif cid == 1
        runlist = "recipe[#{cookbook_name}::deploy],recipe[storm::supervisor]"
      elsif cid == 2
        runlist = "recipe[#{cookbook_name}::deploy],recipe[storm::drpc]"
      end
      payload =<<EOF
#!/bin/bash -e
        #{knife_bin} openstack server create --environment #{environment_name} -f 2 -I #{image_id} --node-name #{cluster_name}-#{cid} -S #{tenant_name} -i /home/ubuntu/workspace/chef/.chef/p_and_i.pem --no-host-key-verify -r \"#{runlist}\" -x ubuntu --nics '[{ \"net_id\": \"df18aba9-7daf-41fe-bb2a-82c586a686fc\" }]' --bootstrap-network vlan2020 --user-data ~/user-data/staging_users.cloud_config
EOF
      DCell::Node[node][:basic].async.exec(DCell.me.id, payload, @ko_opts, track_job)
    end
  end

  def all_successful?
    all_success = true
    @job_tracker.keys.each do |key|
      all_success = false if @job_tracker[key]['exitstatus'] == false
    end
    all_success
  end

  def job_complete(sender_id, job_id, status)
    userlog "JOB COMPLETE: #{job_id}, Exitstatus: #{status}"
    @job_tracker[job_id]['exitstatus'] = status
    @job_tracker[job_id]['running'] = false
    status
  end

  def launch_generic(cookbook_name, cluster_size=1, node="app2")
    #image_id = "02b5d86b-7d8f-4b51-a191-9a0a15596ea6" # Precise 12.04
    image_id = "caa89f87-cae1-4354-960f-793913800aab" # service-image-38-stage , not sure why we use this.. but ZK isn't doing apt-get update.. grr 
    working_dir = File.join(ENV['COOKBOOK_DIR'], cookbook_name)
    environment_name = "#{cookbook_name}-#{ENV['MYTAG']}"
    tenant_name = "p_and_i"
    cluster_name = "#{cookbook_name}-#{ENV['MYTAG']}-0"

    delete_if_exists(cluster_name)

    cluster_size.times do |cid|
      payload =<<EOF 
#!/bin/bash -e
        #{knife_bin} openstack server create --environment #{environment_name} -f 2 -I #{image_id} --node-name #{cluster_name}-#{cid} -S #{tenant_name} -i /home/ubuntu/workspace/chef/.chef/p_and_i.pem --no-host-key-verify -r \"recipe[#{cookbook_name}::deploy]\" -x ubuntu --nics '[{ \"net_id\": \"df18aba9-7daf-41fe-bb2a-82c586a686fc\" }]' --bootstrap-network vlan2020
EOF
      DCell::Node[node][:basic].async.exec(DCell.me.id, payload, @ko_opts, track_job)
    end
    true
  end

  def launch_cluster(cookbook_name, cluster_size=1, node="app2")
    if cookbook_name == "lookout-storm"
      launch_storm(cookbook_name, cluster_size, node)
    else
      launch_generic(cookbook_name, cluster_size, node)
    end
    true
  end

  def berks_refresh(cookbook_name, node="app2")
    working_dir = File.join(ENV['COOKBOOK_DIR'], cookbook_name)
    payload =<<EOF
#!/bin/bash -e
      echo "changing dir to #{working_dir}"
      cd #{working_dir}
      berks install
      berks update
      #berks upload #{cookbook_name} --force
      berks upload --force
EOF
    DCell::Node[node][:basic].exec(DCell.me.id, payload, @ko_opts, track_job)
  end

  def berks_install(cookbook_name, node="app2")
    working_dir = File.join(ENV['COOKBOOK_DIR'], cookbook_name)
    payload =<<EOF
#!/bin/bash -e
      echo "changing dir to #{working_dir}"
      cd #{working_dir}
      berks install
EOF
    DCell::Node[node][:basic].exec(DCell.me.id, payload, @ko_opts, track_job)
    main_menu
  end

  def berks_update(cookbook_name, node="app2")
    working_dir = File.join(ENV['COOKBOOK_DIR'], cookbook_name)
    payload =<<EOF
#!/bin/bash -e
      echo "changing dir to #{working_dir}"
      cd #{working_dir}
      berks update
EOF
    DCell::Node[node][:basic].exec(DCell.me.id, payload, @ko_opts, track_job)
  end

  def berks_upload(cookbook_name, node="app2")
    working_dir = File.join(ENV['COOKBOOK_DIR'], cookbook_name)
    payload =<<EOF
#!/bin/bash -e
      echo "changing dir to #{working_dir}"
      cd #{working_dir}
      #berks upload #{cookbook_name} --force
      berks upload --force
EOF
    DCell::Node[node][:basic].exec(DCell.me.id, payload, @ko_opts, track_job)
  end
end
