#!/bin/bash -ex

DEST_DIR=/mnt/ebs

cat <<EOM> $DEST_DIR/etc/pacman.d/mirrorlist
Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch
EOM

# pv-grub's menu.lst
mkdir -p $DEST_DIR/boot/grub
cat <<EOF> $DEST_DIR/boot/grub/menu.lst
# This file is only used on paravirtualized instances.
timeout 1
default 0
color   light-blue/black light-cyan/blue
title  Arch Linux
root   (hd0)
kernel /boot/vmlinuz-linux root=/dev/xvda1 ro rootwait rootfstype=ext4 nomodeset console=hvc0 earlyprintk=xen,verbose loglevel=7
initrd /boot/initramfs-linux.img
EOF

# fstab generation
cat <<EOFS> $DEST_DIR/etc/fstab
# Generated
tmpfs   /tmp  tmpfs nodev,nosuid,size=4G  0 0
/dev/xvda1 /          ext4        rw,noatime,data=ordered  0 1
EOFS

# Networking: setup DHCP
cat <<EONET> $DEST_DIR/etc/network.d/eth0
CONNECTION='ethernet'
HOSTNAME=''
INTERFACE='eth0'
IP='dhcp'
DHCLIENT='yes'
EONET

cat <<EON> $DEST_DIR/etc/conf.d/netcfg
NETWORKS=(eth0)
WIRED_INTERFACE="eth0"
EON

# LOCALE config
cat <<ELOCALE> $DEST_DIR/etc/locale.conf
LANG="en_US.UTF-8"
ELOCALE

cat <<ELGEN> $DEST_DIR/etc/locale.gen
en_AU.UTF-8 UTF-8
en_DK.UTF-8 UTF-8
en_US.UTF-8 UTF-8
ELGEN

# SSHd config
cat <<EOSSH> $DEST_DIR/etc/ssh/sshd_config
Protocol 2
RSAAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes
PermitEmptyPasswords no
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePrivilegeSeparation sandbox
UsePAM yes
Subsystem sftp  /usr/lib/ssh/sftp-server
EOSSH
