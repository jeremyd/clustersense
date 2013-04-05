#!/bin/bash -e

# the make deps from AUR
pacman -S --noconfirm redis openvpn zeromq
packer -S --noconfirm jruby
jruby -S gem install bundler

pacman -S --noconfirm ruby
pacman -S --noconfirm libxml2 libxslt lsb-release
gem install bundler --no-user

#TODO: get a public repo so we can clone easy

systemctl enable ami-agents@basic.service
systemctl enable ami-agents@reelweb.service

cat <<EOF> /etc/ami-agents/basic.yml
node_id: homebase
node_ip: 10.8.0.1
port: '4001'
registry_host: 10.8.0.1
EOF

cat <<EOT> /etc/ami-agents/reelweb.yml
node_id: reelweb
node_ip: 10.8.0.1
port: '4002'
registry_host: 10.8.0.1
EOT
