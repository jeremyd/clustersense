#!/bin/bash -e

export DEBIAN_FRONTEND=noninteractive

echo "adding percona repository key to system"
apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A

echo "adding percona repository config to /etc/apt/sources.list.d/percona.list"
echo "deb http://repo.percona.com/apt precise main" > /etc/apt/sources.list.d/percona.list
apt-get update

echo "installing percona 5.5"
apt-get install percona-server-server-5.5 percona-server-client-5.5 -y
apt-get install xtrabackup -y

# TODO echo the datadir onto /etc/mysql/debian.cnf??
# [mysqld]
# datadir = /var/lib/mysql

echo "done installing percona 5.5"
