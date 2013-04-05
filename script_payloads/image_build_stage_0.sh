#!/bin/bash -e
#
## This script facilitates building for ec2
#

# Stage 0 - just the pacstrap.  and setup pacman.?

if [ -z "$DEST_DIR" ]; then
  echo "you MUST set the environment variable DEST_DIR to the location of the image's filesystem."
  #exit 1
  echo "just setting it to /mnt/ebs."
  DEST_DIR=/mnt/ebs
fi

mkdir -p $DEST_DIR
mount /dev/xvdk $DEST_DIR
cd $DEST_DIR

# TODO: add in lsb-release utilities (Linux Standard Base)
# TODO: add build tools?  autoconf

pacstrap -M -G -d $DEST_DIR base base-devel openssh vim jdk7-openjdk wget curl util-linux xfsprogs jfsutils e2fsprogs btrfs-progs git subversion zsh inetutils iproute2 iputils net-tools zlib netcfg pacmatic grub-bios grub-common dhclient rsyslog python2 python2-yaml python2-configobj python2-distribute sudo tmux arch-install-scripts
cd ..
