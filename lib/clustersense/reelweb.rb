require 'reel'

class TimeServer
  include Celluloid
  include Celluloid::Notifications

  def gen_json_world
    nodelist = DCell::Node.all
    @message_list ||= []
    @wizards ||= []
    gen = { "nodes" => [], "messages" => @message_list, "payloads" => @payload_list, "wizards" => @wizards }
    # grab the next wizard
    nodelist.each_with_index do |n,index|
      x = (40 + (index*100))
      if(((index+1) % 2) == 1)
        y = 50;
      else 
        y = 50;
      end
      xx = (x + 50)
      yy = (y + 50)
      gen["nodes"] << {
        "id" => n.id,
        "addr" => n.addr,
        "state" => n.state.to_s,
        "x" => x,
        "y" => y,
        "xx" => xx,
        "yy" => yy
      }
    end
    return gen.to_json
  end

  #This method is called by the basic cells to remind reelweb they're active
  def keepalive(from_id)
    STDOUT.puts "got a keepalive from #{from_id}"
    return true
  end

  def ping(from_id, message)
    puts "got a ping from #{from_id} with #{message}"
    @message_list ||= []
    #discard a message off the stack
    _ = @message_list.pop if @message_list.length > 1024
    #push the new message onto the list
    compose_message = "#{Time.now.to_s} received from #{from_id}: #{message}"
    @message_list.unshift(compose_message)
    #refresh_node_list
    true
  end

  def add_wizard(from_id, wizard_html, response_uuid)
    @wizards ||= []
    new_wiz = { "html" => wizard_html, "from_id" => from_id, "response_uuid" => response_uuid }
    @wizards.push(new_wiz)
# DONE: can we dynamically add a PUT/POST callback here? with a unique url? that'd be cool..
    DCell::Node[DCell.me.id][:reel].wizard_route_for(new_wiz)
  end

  def rm_wizard(wiz)
    @wizards.reject! { |w| w["response_uuid"] == wiz["response_uuid"] }
  end

  # Accepts an Array of payload script names
  def set_payload_list(list)
    @payload_list = list
  end

  # frames per second throttle.. this refreshes the node list + renders the json
  def set_resolution(interval)
    every(interval) {
      refresh_node_list
    }
  end

# whenever a node comes online it pings this
  def refresh_node_list
    publish 'time_change', gen_json_world 
  end
end

class TimeClient
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger

  def initialize(websocket)
    info "Streaming json_world_view changes to client"
    @socket = websocket
    subscribe('time_change', :notify_time_change)
  end

  def notify_time_change(topic, new_time)
    @socket << new_time
  rescue Reel::SocketError
    info "Time client disconnected"
    terminate
  end
end

class WebServer < Reel::Server
  include Celluloid::Logger

  def initialize(host, port)
    @host = host
    @port = port
    @wizards = []
    info "Reelweb http server starting on #{@host}:#{@port}"
    super(@host, @port, &method(:on_connection))
  end

  def on_connection(connection)
    while request = connection.request
      case request
      when Reel::Request
        info "request for #{request.url}"
        route_request connection, request
      when Reel::WebSocket
        info "Received a WebSocket connection"
        route_websocket request
      end
    end
  end

  # API: called when adding a new wizard by way of TimeClient
  def wizard_route_for(new_wiz)
    puts "received new wizard_route_for #{new_wiz['response_uuid']}"
    @wizards.push(new_wiz)
  end

  def wizard_urls
    urls = []
    @wizards.each do |w|
      urls << w["response_uuid"]
    end
    urls
  end

  def wizard_route_handler(connection, request)
    if wizard_urls.include? request.url
      this_wiz = @wizards.select {|w| w["response_uuid"] == request.url}.first
      handle_wizard_request(connection, request, this_wiz)
    end
  end

  def handle_wizard_request(connection, request, this_wiz)
    #DCell::Node[this_wiz[:from_id]][:ping].wizard_response(this_wiz)
    # this should just display the response in create_image_wizard (or anything implementing ping)
    puts "serving up a wizard callback"
    this_wiz["response"] = request.body
    DCell::Node[this_wiz["from_id"]][:ping].async.wizard_complete(DCell.me.id, this_wiz["response_uuid"], this_wiz["response"])
    DCell::Node[DCell.me.id][:time_server].async.rm_wizard(this_wiz)
    @wizards.reject! { |w| w["response_uuid"] == this_wiz["response_uuid"] }
    #thanks = Reel::Response.new(200, { "Content-Location" => "/", "Location" => "/" }, "thanks here is some text response to quench your jquery thirst for datas")
    thanks = Reel::Response.new(:ok, "thanks here is some text response to quench your jquery thirst for datas")
    connection.respond(thanks)
  end

  def route_request(connection, request)
    if request.url == "/"
      return render_index(connection)
    end
    if request.url == "/clustersense.js"
      return render_ami_agents_js(connection)
    end
    if request.url =~ /\/sprites\/(.+)/
      return render_sprite(connection, $1)
    end
    if request.url =~ /\/(css\/.+)/ || request.url =~ /\/(js\/.+)/ || request.url =~ /\/(img\/.+)/
      return render_static_asset(connection, $1)
    end
    wizard_route_handler(connection, request)

    info "404 Not Found: #{request.path}"
    connection.respond :not_found, "Not found"
  end

  def render_static_asset(connection, static_path)
    static_file = File.join(Clustersense::config_dir, "..", "static_assets", static_path)
    puts "finding static file: #{static_file}"
    if File.exists?(static_file)
      connection.respond(:ok, File.read(static_file))
    else
      connection.respond(:not_found)
    end
  end

  def route_websocket(socket)
    if socket.url == "/timeinfo"
      TimeClient.new(socket)
    else
      info "Received invalid WebSocket request for: #{socket.url}"
      socket.close
    end
  end

  def render_sprite(connection, spritename)
    connection.respond(:ok, File.read(File.join(Clustersense::config_dir, "..", "sprites", spritename)))
  end

  def render_ami_agents_js(connection)
    info "200 OK: /clustersense.js"
    connection.respond(:ok, File.read(File.join(Clustersense::config_dir, "..", "js", "clustersense.js")))
  end

  def render_index(connection)
    info "200 OK: /"
    connection.respond(:ok, File.read(File.join(Clustersense::config_dir, "..", "static_assets", "html", "index.html")))
  end
end

config_file = @trollop_options[:config] || "config.yml"
config = Clustersense::config(config_file)

DCell.start :id => config["node_id"], :addr => "tcp://#{config["node_ip"]}:#{config["port"]}", "registry" => { "adapter" => "redis", "host" => config["registry_host"], "port" => 6379 }

host = "127.0.0.1"
port = "1234"
if config["reelweb_ip"]
  host = config["reelweb_ip"]
elsif config["node_ip"]
  host = config["node_ip"]
end
if config["reelweb_port"]
  port = config["reelweb_port"] 
end

WebServer.supervise_as(:reel, host, port)
TimeServer.supervise_as :time_server

# This controls the world refresh rate
DCell::Node[config["node_id"]][:time_server].set_resolution(1)

#^^^ the slash in response_uuid might be important
