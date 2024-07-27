#!/bin/bash

SIZE="1024"
if [ -n "$1" ]; then SIZE="$1"; fi

dd if=/dev/zero of=/swapfile bs=1m count="$SIZE"
chown 600 /swapfile
mkswap /swapfile
swapon /swapfile
