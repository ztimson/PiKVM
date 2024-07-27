#!/bin/bash

# Root check
if [ "$UID" != "0" ]; then
  echo "Error: Please run as root"
  exit 1
fi

# Setup
rw
git clone https://git.zakscode.com/ztimson/PiKVM.git
cd PiKVM

# Static MAC fix
printf "Enable static MAC (y/n): " && read YN
if [ "$YN" =~ [Yy]$ ]; then
  printf "Define vendor ID (defaults to Intel): " && read MAC_PREFIX
  if [ -z "$MAC_PREFIX" ]; then MAC_PREFIX="80:86:00"; fi

  cat <<EOF >> /etc/systemd/network/

[Link]
MACAddress=$(printf '%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
EOF

  cat <<EOF >> /etc/systemd/network/

[Link]
MACAddress=$(printf '%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
EOF
fi

pacman -S cronie python-pipx
pipx install pillow RPI.GPIO spidev
