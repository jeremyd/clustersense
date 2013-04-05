#!/bin/bash

# TODO, there's not enough entropy to do this on a fresh machine..
# TODO was this interactive?
pacman-key --init
pacman-key --populate
pacman -Syu --noconfirm


