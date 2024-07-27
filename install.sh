#!/bin/bash

# Root check
if [ "$UID" != "0" ]; then
  echo "Error: Please run as root"
  exit 1
fi

# Setup
rw
./bin/swap-manager.sh

git status > /dev/null
if [ "$?" != "0" ]; then
  echo "Missing dependencies, cloning..."
  git clone https://git.zakscode.com/ztimson/PiKVM.git
  cd PiKVM
fi

# Static MAC fix
echo ""
read -p "Enable static MAC (y/n): " YN
if [ "${YN,,}" == "y" ]; then
  printf "Define vendor ID (defaults to Intel): " && read MAC_PREFIX
  if [ -z "$MAC_PREFIX" ]; then MAC_PREFIX="80:86:00"; fi

  files=(
    "/etc/systemd/network/eth0.network"
    "/etc/systemd/network/wlan0.network"
  )

  for file in "${files[@]}"; do
    if [ -n "$(cat $file | grep MACAddress )" ]; then continue; fi
    mac_address=$(printf '%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
    cat <<EOF >> "$file"

[Link]
MACAddress=$MAC_PREFIX:$mac_address
EOF
  done
fi

# pacman -S cronie python-pipx
# pipx install pillow RPI.GPIO spidev

./bin/swap-manager.sh --disable
