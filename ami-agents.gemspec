Gem::Specification.new do |s|
  s.name = "ami-agents"
  s.version = "0.0.1"
  s.summary = "ami-agents"
  s.authors = [ "Jeremy Deininger" ]
  s.email = [ "jeremydeininger@gmail.com" ]
  s.executables = ["ami-agents"]
  s.bindir = "bin"
  s.files = Dir.glob("lib/**/*.rb") + \
    Dir.glob("test/**/*.rb") + \
    Dir.glob("systemd/*") + \
    Dir.glob("user-data/*") + \
    Dir.glob("config/config.yml.example")
  s.add_dependency("celluloid", ">=0.13.0")
  s.add_dependency("celluloid-zmq", ">=0.13.0")
  s.add_dependency("celluloid-io", ">=0.13.0")
  s.add_dependency("dcell", ">=0.13.0")
  s.add_dependency("reel", ">=0.0.2")
  s.add_dependency("ffi-rzmq", ">=0.9.7")
  s.add_dependency("aws-sdk", ">=1.7.1")
  s.add_dependency("trollop", ">=2.0")
  s.add_dependency("highline")
  s.add_dependency("pry")
end
