#!/bin/bash -ex
cat <<EOF> /etc/mkinitcpio.conf
MODULES="xfs dm_mod"
BINARIES=""
FILES=""
HOOKS="base udev autodetect modconf block usbinput lvm2 filesystems usr fsck shutdown"
EOF
mkinitcpio -p linux
