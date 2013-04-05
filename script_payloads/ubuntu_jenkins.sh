#!/bin/bash -e
wget https://s3-us-west-1.amazonaws.com/ebssense/ebssense_0.0.1-16.deb
sudo apt-get update
set +e
sudo dpkg -i ebssense_0.0.1-16.deb
sudo apt-get -f -y install
set -e
sudo -E ebssense db_migrate
sudo -E ebssense list --sync jenkins-sense
sudo -E ebssense restore --name jenkins-sense

wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get install jenkins git
sudo /etc/init.d/jenkins stop
sudo mv /var/lib/jenkins /var/lib/jenkins.OLD
sudo mkdir -p /var/lib/jenkins
sudo mount -o bind /mnt/jenkins-sense/var/lib/jenkins /var/lib/jenkins
sudo /etc/init.d/jenkins start

#gerrit
sudo addgroup gerrit2
sudo adduser --system --home /mnt/jenkins-sense/gerrit2 --shell /bin/bash --ingroup gerrit2 gerrit2
cd /mnt/jenkins-sense/gerrit2
wget https://gerrit.googlecode.com/files/gerrit-full-2.5.2.war

# SETUP SUDOERS FOR JENKINS

# this was only for the init, grab the gerrit upstart script we built for startup?..
java -jar gerrit-2.4.2.war init -d /usr/local/gerrit2
sudo su -c '/mnt/jenkins-sense/gerrit2/bin/gerrit.sh start' gerrit2
