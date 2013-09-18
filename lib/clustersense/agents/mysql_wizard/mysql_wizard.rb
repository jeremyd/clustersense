require 'clustersense/agents'
require 'clustersense/wizards'
require 'uri'

class AwsMenus
  include Wizards
  include Celluloid

  def initialize
    @agreements ||= {}
  end

  def mysql_slave_node
    mysql_slave_node = DCell::Node.all.detect do |n| 
      n.id =~ /^mysql_slave/ 
    end.id
  end

  def mysql_master_node
    mysql_master_node = DCell::Node.all.detect do |n| 
      n.id =~ /^mysql_master/ 
    end.id
  end

  def all_mysql
    all_mysql_nodes = [mysql_master_node, mysql_slave_node]
  end

  def main_menu()
    question = "Mysql Wizard"
    the_choices = {
      "Install Mysql 5.5" => 
          ->(response){ install_mysql_menu() },
      "Initialize Slave from Master" => 
          ->(response){ init_slave_menu() },
      }
    choices(question, the_choices.keys, true) do |choice|
      the_choices[choice].call(choice)
    end
  end

  def script_payloads_dir
    script_payloads_dir = File.join(Clustersense::AGENTS_DIR, "mysql_wizard", "script_payloads")
  end

  def install_mysql_menu()
    install_mysql_payload = File.join(script_payloads_dir, "install_percona.sh")
    choices("Install mysql 5.5 on which node?", all_mysql) do |choice|
       # install mysql on the slavemysql install complete on the slavemysql install complete on the slave
      if DCell::Node[choice][:basic].exec(DCell.me.id.to_s, ::IO.read(install_mysql_payload))
        userlog "*** MYSQL INSTALLED ON #{choice}"
      else
        userlog "FATAL: mysql installation failed on the #{choice}, aborting"
      end
      main_menu
    end
  end

  def init_slave_menu()
    available_scripts = Dir.glob(File.join(script_payloads_dir, "*")).collect {|c| File.basename(c)}

    create_user_payload = File.join(script_payloads_dir, "create_pam_user.sh")
    del_user_payload = File.join(script_payloads_dir, "rm_pam_user.sh")
    stream_backup_payload = File.join(script_payloads_dir, "innobackupex_master_to_slave.sh")
    slave_init_payload = File.join(script_payloads_dir, "slave_init.sh")

    all_mysql_nodes = all_mysql

    # setup ssh users for streaming the backup.
    userlog "*** ADDING SSH USER FOR STREAMING BACKUP"
    all_mysql_nodes.each do |mysql_node|
      DCell::Node[mysql_node][:basic].exec(DCell.me.id.to_s, ::IO.read(del_user_payload).to_s, "PAM_USERNAME" => "mysqlbackup")
      pub = "#{ENV['PRIVATE_SSH_KEY']}.pub"
userlog pub
userlog ::IO.read(pub).to_s
      DCell::Node[mysql_node][:basic].exec(DCell.me.id.to_s, ::IO.read(create_user_payload).to_s, "PAM_USERNAME" => "mysqlbackup", "PRIVATE_SSH_KEY" => ::IO.read(ENV['PRIVATE_SSH_KEY']).to_s, "PUBLIC_SSH_KEY" => ::IO.read("#{ENV['PRIVATE_SSH_KEY']}.pub").to_s)
    end

    # on master run the innobackupex with streaming over to the slave
    slave_ip = URI.parse(DCell::Node[mysql_slave_node].addr).host
    userlog "*** RUNNING STREAMING BACKUP FROM MASTER TO SLAVE: #{slave_ip}"
    if DCell::Node[mysql_master_node][:basic].exec(DCell.me.id.to_s, ::IO.read(stream_backup_payload).to_s, 'SLAVE_HOST' => slave_ip)
      userlog "*** BACKUP TRANSFER COMPLETE"
      # on slave run wipe, replaylog, initialize from backup
      if DCell::Node[mysql_slave_node][:basic].exec(DCell.me.id.to_s, ::IO.read(slave_init_payload).to_s)
        userlog "*** APPLY LOG SUCCESS"
      else
        userlog "*** FATAL: APPLY LOG FAILED, ABORTING."
      end
    else
      userlog "FATAL: backup failed, aborting."
    end
    main_menu
  end
end

config_file = @trollop_options[:config]
config = Clustersense::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "zk", "servers" => [config["registry_host"]], "port" => 2181 }

AwsMenus.supervise_as :ping

DCell::Node[config["node_id"]][:ping].main_menu
