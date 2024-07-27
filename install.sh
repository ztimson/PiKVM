#!/bin/bash

# Root check
if [ "$UID" != "0" ]; then
    echo "Error: Please run as root"
    exit 1
fi

# Setup
rw

# Install git
if [ -z "$(which git)" ]; then
    echo "Installing Git..."
    pacman -S --noconfirm git
fi

# Pull repo/dependencies & re-run from there
git status > /dev/null
if [ "$?" != "0" ]; then
    echo "Missing dependencies, cloning..."
    git clone https://git.zakscode.com/ztimson/PiKVM.git
    cd PiKVM
    ./install.sh
    exit
fi

echo "Running updates, this might take a few minutes..."
pikvm-update

# Fix banner
echo ""
echo "Updating the banner..."
cp motd /etc/motd

# Update Hostname
echo ""
read -p "Change hostname (Blank to skip): " $H
if [ -n "$H" ]; then
    sed -i "s/$HOSTNAME/$H" /etc/hostname
    sed -i "s/$HOSTNAME/$H" /etc/hosts
fi

# Static MAC fix
echo ""
read -p "Enable static MAC (y/n): " YN
if [ "${YN,,}" == "y" ]; then
    printf "Define vendor ID (Default (Intel): 80:86:00): " && read MAC_PREFIX
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

# Access point
echo ""
read -p "Enable access point on network outage (y/n): " YN
if [ "${YN,,}" == "y" ]; then
    pacman -Sy --noconfirm cronie
    echo ""
    echo "Access Point: $SSID"
    while true; do
        read -p "Password: " PASSWORD
        if [ ${#PASSWORD} -ge 8 ]; then break; fi
        echo "Error: Minimum 8 characters"
    done
    bin/access-point.sh -f --passwd $PASSWORD
fi

echo ""
read -p "Enable E-Ink display (y/n): " YN
if [ "${YN,,}" == "y" ]; then
    ./bin/swap-manager.sh 1024

    pacman -Sy --noconfirm python-pipx
    pipx install pillow
    pipx install RPI.GPIO
    pipx install spidev

    ./bin/swap-manager.sh --disable
fi

echo ""
echo "Setup Complete! Please reboot..."
