#!/bin/bash

dd if=/dev/zero of=/swapfile bs=1m count=1024
chown 600 /swapfile
mkswap /swapfile
swapon /swapfile
