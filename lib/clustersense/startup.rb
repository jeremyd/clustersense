class Upstart
  def self.enable(agent_name, config)
    x = <<EOF
#!upstart
description "Clustersense Agent Startup"

start on [12345]
stop on [!12345]

console log

exec clustersense --agent #{agent_name} --config #{config}
EOF
    begin
      File.open("/etc/init/clustersense_#{agent_name}.conf","w") do |f|
        f.write(x)
      end
    rescue
      puts "ERROR: failed to write to /etc/init/clustersense_#{agent_name}.conf.  (Permissions?)"
      exit 1
    end
    puts "clustersense agent config for #{agent_name} enabled in upstart"
  end
end
