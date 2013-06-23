#!/usr/bin/ruby

vendorlib = File.expand_path(File.join(File.dirname(File.realpath(__FILE__)), "..", "bundle", "bundler", "setup.rb"))
hardvendor = "/usr/lib/clustersense-git/bundle/bundler/setup.rb"
puts "vendorlib was #{vendorlib}"
if File.exists?(vendorlib)
  require vendorlib
elsif File.exists?(hardvendor)
  puts "luckily we have a hardcoded vendor directory for archlinux #{hardvendor}, requiring."
  require hardvendor
else
  puts "FATAL: you must run bundle install --standalone; or could not find the vendor directory #{vendorlib}"
  exit 1
end

require 'clustersense'

@trollop_options = {}
#@trollop_options[:config] = "test/homebase-test.yml"
#require 'clustersense/basic'
#sleep 2

@trollop_options[:config] = "test/reelweb-test.yml"
require 'clustersense/reelweb'
sleep 2
@trollop_options[:config] = "test/create-image-test.yml"
require 'clustersense/create_image_wizard'

#DCell::Node[config["node_id"]][:time_server].add_wizard(DCell.me.id, "<h1>HI YO, I CAN HAS WISARD?</h1>", "/poormancrypto")
say "agents started"
sleep
