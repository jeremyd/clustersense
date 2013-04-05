#!/bin/bash
#STDOUT.puts "HELLLO STDOUT"
#STDERR.puts "HELLOOOO STEDERR"
#
#exit 0

#pacman -Q |grep ruby
#cd /root/ebssense
#gem install bundler --no-user
#bundle install --standalone

#cd /root/ebssense
#bin/ebssense --help

#cd /root/ebssense
#bin/ebssense build --name anotherEBS --num-vol 3 --size-vol 6 --mount-point /mnt/anotherEBS --device-letters s t u

cd /root/ebssense
bin/ebssense test

lvdisplay
