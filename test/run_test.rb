#!/usr/bin/env ruby

###
## This is an experimental integration test harness for clustersense agents.
###

# if running direct from checkout load the local clustersense libs first
vendorlib = File.expand_path(File.join(File.dirname(File.realpath(__FILE__)), "..", "bundle", "bundler", "setup.rb"))
# linux packages use a 'hardvendor' directory
hardvendor = "/var/lib/clustersense/bundle/bundler/setup.rb"
if File.exists?(vendorlib)
  puts "vendorlib is #{vendorlib};"
  require vendorlib
elsif File.exists?(hardvendor)
  puts "vendorlib is #{hardvendor};"
  require hardvendor
else
  puts "FATAL: you must run bundle install --standalone; or could not find the vendor directory #{vendorlib} || #{hardvendor}"
  exit 1
end

require 'clustersense'

@trollop_options = {}

@trollop_options[:config] = "test/app1.yaml"
require 'clustersense/basic'

@trollop_options[:config] = "test/reelweb.yaml"
require 'clustersense/reelweb'

@trollop_options[:config] = "test/script_wizard.yaml"
require 'clustersense/script_wizard'

puts "agents started"
puts "point your selenium and humans at http://localhost:1234 to visit. CTRL-C to quit."
sleep
