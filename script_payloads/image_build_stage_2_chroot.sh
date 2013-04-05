#!/bin/bash -ex

#
## This chroot script was used to finish the archlinux installation.
#

# TODO: this may not be necessary anymore arch-chroot allows running of systemctl enable (not start). check on it.
# Can not use systemctl here because it's not allowed inside a chroot.
# ARG 1 is the name of the service, ie: sshd.service
# ARG 2 (optional) path to systemd service file
function enableservice {
  if [ -n "$2" ]; then
    usepath=$2
  else
    usepath=/usr/lib/systemd/system
  fi
  if [ ! -f /etc/systemd/system/multi-user.target.wants/$1 ]; then
    ln -s $usepath/$1 /etc/systemd/system/multi-user.target.wants/$1 ||true
  else
    echo "skipping enabling the service $1 because it's already enabled."
  fi
}

# drop in some AUR package(s)

MK_PKG_OPTS="--syncdeps --install --asroot --noconfirm --noprogressbar"
AUR_PATH="/aur"

# ARG 1 is name of aur package to make and install
# ARG 2 is url of PKGBUILD tarball
function aurinst {
  mkdir -p $AUR_PATH
  cd $AUR_PATH
  if pacman -Q $1; then
    echo package already installed: $1.  skipping makepkg.
  else
    curl $2 -o $1.tar.gz
    tar -xzvf $1.tar.gz
    cd $1
    makepkg $MK_PKG_OPTS
    cd ..
  fi
}

# linux-ec2 kernel 
# ugh, takes forever :) try stock for a bit
#export MAKEFLAGS=-j8
#if pacman -Q linux; then
#  echo removing linux package so we can install linux-ec2
#  pacman -R --noconfirm linux
#fi
#aurinst linux-ec2 https://aur.archlinux.org/packages/li/linux-ec2/linux-ec2.tar.gz

# packer an AUR helper
aurinst packer https://aur.archlinux.org/packages/pa/packer/packer.tar.gz

# ec2 tools
aurinst ec2-api-tools https://aur.archlinux.org/packages/ec/ec2-api-tools/ec2-api-tools.tar.gz

# cloud-init deps
# these aur deps were moved to community, cloud-init should pull them in
#pacman -Sy --noconfirm python2-cheetah python2-boto
aurinst python2-prettytable https://aur.archlinux.org/packages/py/python2-prettytable/python2-prettytable.tar.gz
aurinst python2-oauth2 https://aur.archlinux.org/packages/py/python2-oauth2/python2-oauth2.tar.gz
aurinst python2-argparse https://aur.archlinux.org/packages/py/python2-argparse/python2-argparse.tar.gz
aurinst cloud-init https://aur.archlinux.org/packages/cl/cloud-init/cloud-init.tar.gz

# Enable the necessary services.
enableservice netcfg.service
enableservice sshd.service
enableservice sshdgenkeys.service
enableservice syslog-ng.service
enableservice cloud-init.service /etc/systemd/system
enableservice cloud-config.service /etc/systemd/system
enableservice cloud-final.service /etc/systemd/system

# generate locale, setup timezone to UTC.
locale-gen
if [ ! -f /etc/localtime ]; then
  ln -s /usr/share/zoneinfo/UTC /etc/localtime
fi
