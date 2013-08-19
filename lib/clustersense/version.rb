module Clustersense
  VERSION = "0.0.1"
  AGENTS_DIR = File.expand_path(File.join(File.dirname(__FILE__)))
  def self.config_dir
    File.expand_path(File.join(AGENTS_DIR, "..", "..", "config"))
  end

  def self.system_wide_conf
    "/etc/clustersense"
  end

  def self.config(config_file = "config.yml")
    localconf = File.join(self.config_dir, config_file)
    systemconf = File.join(self.system_wide_conf, config_file)
    if File.exists?(localconf)
      YAML::load(IO.read(localconf))
    elsif File.exists?(systemconf)
      YAML::load(IO.read(systemconf))
    else
      puts "FATAL: could not load a config to match #{config_file} from #{self.system_wide_conf} or from #{self.config_dir}"
      exit 1
    end
  end
end
