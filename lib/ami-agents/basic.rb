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

  # start talking to reelweb at this interval
  def set_resolution(interval)
    every(interval) {
      keepalive_reelweb
    }
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

  def keepalive_reelweb
    if DCell::Node["reelweb"] && DCell::Node["reelweb"][:time_server]
      DCell::Node["reelweb"][:time_server].keepalive(DCell.me.id)
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
    #tmpgem = File.join(Dir.tmpdir, "ami-agents-0.0.1.gem") 
    #exec("curl -o #{tmpgem} #{new_code}")
    #exec("mkdir -p /etc/ami-agents")
    #exec("cp /usr/lib/ruby/gems/1.9.1/gems/ami-agents-0.0.1/config/config.yml /etc/ami-agents/config.yml")
    #exec("gem install #{tmpgem} --no-user")
    #exec("cp /etc/ami-agents/config.yml /usr/lib/ruby/gems/1.9.1/gems/ami-agents-0.0.1/config/config.yml")
    #exec("systemctl restart ami-agents")
    #exit(0)
    # 2) engineer new dcell service via systemd, and start it.
    # 3) dispatch checks the new cell is online
    # 4) shutdown old cell
  end

  # This executes a script in a chroot using arch-chroot!
  # For use with image building
  # This method accepts any script payload with a shebang line.
  # Also accepts optional environment hash that will be turned into local environment variables for the script to access.
  def exec_chroot(sender_id, script, chroot_dir, environment = {})
    # writeout the script into the chroot
    datetimestring = Time.now.strftime("%Y%m%d-%H%M-%L")
    script_hist = File.join(chroot_dir, "ami_agents_scripts_history")
    FileUtils.mkdir_p(script_hist)
    tmp_script_path = File.join(script_hist, datetimestring)
    chroot_relative_path_to_script = File.join("/ami_agents_scripts_history", File.basename(tmp_script_path))
    File.open(tmp_script_path, "w") { |f| f.write(script) }
    FileUtils.chmod(0755, tmp_script_path)
    onebigout = ""
    ::IO.popen(["arch-chroot", chroot_dir, chroot_relative_path_to_script, :err=>[:child, :out]], "r+") do |io|
      while(1) do
        begin
          output = io.readpartial(100000)
          if send_this = unshift_stdin
            io.puts(send_this)
          end
          # TODO: flip these rescues?
        rescue => e
          output = "gotepipe"
          break
        rescue EOFError => e
          output = "done."
          break
        end
        #ping_someone("reelweb", :time_server, output)
        ping_someone(sender_id, :ping, output) if output
      end
    end
    if $?.success?
      success_status = "Success in the chroot!"
    else
      success_status = "Failed in the chroot!"
    end
    ping_someone(sender_id, :ping, success_status)
    return $?.success?
  end

  # This method accepts any script payload with a shebang line.
  # Also accepts optional environment hash that will be turned into local environment variables for the script to access.
  def exec(sender_id, script, environment = {})
    @cache_path ||= "/var/cache/ami-agents/exec"
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
        #ping_someone("reelweb", :time_server, output)
        ping_someone(sender_id, :ping, output) if output
      end
    end
    if $?.success?
      success_status = "Success!!"
    else
      success_status = "Failed!!"
    end
    #ping_dispatch("#{success_status}#{onebigout}")
    ping_someone(sender_id, :ping, success_status)
    return $?.success?
  end
end

config_file = @trollop_options[:config] || "config.yml"
config = AmiAgents::config(config_file)
DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "redis", "host" => config["registry_host"], "port" => 6379 }

Basic.supervise_as :basic
