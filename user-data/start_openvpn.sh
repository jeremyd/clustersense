#!/bin/bash
systemctl enable openvpn@server.service
systemctl start openvpn@server
systemctl restart redis
/opt/jenkins/bin/jenkins start
