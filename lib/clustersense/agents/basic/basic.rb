require 'time'

class Basic
  attr_accessor :config_file
  include Celluloid
  
  def available
    return true
  end

  #push a message to be delivered ..
  def push_stdin(message)
    @stdin_messages ||= []
    @stdin_messages.push(message)
  end

  def unshift_stdin
    @stdin_messages ||= []
    return nil if @stdin_messages.empty?
    @stdin_messages.unshift
  end

  # cell -> String (name of cell)
  # actor -> Symbol (name of actor)
  # message -> String
  def ping_someone(cell, actor, message)
    if DCell::Node[cell] && DCell::Node[cell][actor]
      DCell::Node[cell][actor].async.ping(DCell.me.id, message)
      return true
    else
      return false
    end
  end

  # Receives a git repository with new code? Or just some files? Or a gem?
  def infect(new_code)
    result = ""
    # TODO: do a self update and restart ..
    # 1) install the payload somewhere (gems?)
    #tmpgem = File.join(Dir.tmpdir, "clustersense-0.0.1.gem") 
    #exec("curl -o #{tmpgem} #{new_code}")
    #exec("mkdir -p /etc/clustersense")
    #exec("cp /usr/lib/ruby/gems/1.9.1/gems/clustersense-0.0.1/config/config.yml /etc/clustersense/config.yml")
    #exec("gem install #{tmpgem} --no-user")
    #exec("cp /etc/clustersense/config.yml /usr/lib/ruby/gems/1.9.1/gems/clustersense-0.0.1/config/config.yml")
    #exec("systemctl restart clustersense")
    #exit(0)
    # 2) engineer new dcell service via systemd, and start it.
    # 3) dispatch checks the new cell is online
    # 4) shutdown old cell
  end

  # This method accepts any script payload with a shebang line.
  # Also accepts optional environment hash that will be turned into local environment variables for the script to access.
  def exec(sender_id, script, environment = {})
    @cache_path ||= File.join(Clustersense::config_dir, "..", "exec")
    FileUtils.mkdir_p(@cache_path)
    datetimestring = Time.now.strftime("%Y%m%d-%H%M-%L")

    environment.keys.each do |e|
      ENV[e] = environment[e]
    end

    tmp_script_path = File.join(@cache_path, datetimestring)

    File.open(tmp_script_path, "w") { |f| f.write(script) }
    FileUtils.chmod(0755, tmp_script_path)
    onebigout = ""
    ::IO.popen([tmp_script_path, :err=>[:child, :out]], "r+") do |io|
      while(1) do
        begin
          output = io.readpartial(100000)
          if send_this = unshift_stdin
            io.puts(send_this)
          end
        rescue => e
          output = "gotepipe"
          break
        rescue EOFError => e
          output = "done."
          break
        end
        ping_someone(sender_id, :ping, output) if output
      end
    end
    if $?.success?
      success_status = "Success!!"
    else
      success_status = "Failed!!"
    end
    ping_someone(sender_id, :ping, success_status)
    return $?.success?
  end
end

config_file = @trollop_options[:config] || "config.yml"
config = Clustersense::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "zk", "servers" => [ config["registry_host"] ], "port" => 2181 }

Basic.supervise_as :basic
