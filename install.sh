#!/bin/bash

if [ "$UID" != "0" ]; then
  echo "Error: Please run as root"
  exit 1
fi

git clone https://git.zakscode.com/ztimson/PiKVM.git
cd PiKVM

pacman -S cronie python-pipx
pipx install pillow RPI.GPIO spidev
