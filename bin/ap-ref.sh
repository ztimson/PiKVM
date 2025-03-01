#!/bin/bash
# Created by srepac@kvmnerds.com
#
# Filename:  hotspot
VER=1.6
## CHANGELOG:
# 1.0   03/02/22    Created
# 1.1   03/03/22    Added ability to always run services at boot (also otgnet network DHCP entry for dnsmasq)
# 1.2   03/04/22    Add ap0 interface on top of wlan0 for use as hotspot AP
# 1.3   03/11/22    Create script/service so that AP starts up on boot and make it easy to change hotspot network
# 1.4   03/12/22    Updated SSID to be hostname-AP; DNSport pick between 53 and 5553; refactoring
# 1.5   03/14/22    Use the current nameservers for use with dnsmasq
# 1.6   03/22/22    Consolidated to one script for usage on both Arch and Raspbian
#
# This script was written to allow PiKVM to run its wifi as hotspot AP akin to how GoPro is first configured
#
#   SSID:         $(hostname)-AP
#   Passphrase:   pikvmisawesome
#
#   Hotspot network IP 10.5.4.1/24   DHCP range 10.5.4.10 - 10.5.4.250
###
# Change SSID and PASSPHRASE here
SSID="$(hostname)-AP"
PASSPHRASE='pikvmisawesome'
# Replace the first 3 octets of hotspot network here (change it to whatever you want)  Default: NETWORK="10.5.4"
NETWORK="10.5.4"
###
: '
Before running this script, you should connect your wifi to SSID first, and then run this script creating ap0
... that acts like a wifi hotspot that other systems can connect to.

In addition, if the pi eth0/wlan0 is connected to internet, the systems connected to the wifi
... hotspot will also have internet access.
' ### end of comments ###

### unblock wifi in the very beginning just in case
rfkill unblock wifi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "usage:  $0 [-f] where -f forces hotspot to run at boot; default is to run on this session only"
  exit 1
fi

if [ -e /usr/local/bin/rw ]; then rw; fi
set -x

### added 03/14/22 - create list of DNS servers from /etc/resolv.conf
if [ ! -e /etc/kvmd/custom.dns ]; then
  NAMESERVERS=$( for i in `grep ^nameserver /etc/resolv.conf | awk '{print $2}' | sort -r -u`; do echo -n "$i,"; done | sed 's/,$//' )
else
  # comma separated list of DNS servers to use
  NAMESERVERS=$( egrep -v '^#' /etc/kvmd/custom.dns )
fi

### Added on 03/22/22 to allow usage on both Arch and Debian (Raspbian) ###
case $( grep ^NAME= /etc/os-release | cut -d'"' -f 2 | cut -d' ' -f1 ) in
  "Arch")
    # Install required packages if not already installed
    if [ $( pacman -Q | grep -wc hostapd ) -ne 1 ]; then
      # first, update db's
      pacman -Syy
      # then, install hostapd and dnsmasq packages
      pacman --noconfirm -S hostapd dnsmasq
    fi
    ;;
  "Debian"|"Raspbian")
    # install required packages if not already installed
    if [ $( apt list 2> /dev/null | grep hostapd | grep -cw installed ) -ne 1 ]; then
      # first, update db's
      apt-get update
      # then, install hostapd and dnsmasq packages
      apt-get install -y hostapd dnsmasq wireless-tools iw
    fi
    ;;
  *)
    echo "Running on unsupported OS.  Exiting."
    exit 1
    ;;
esac

# Delete and re-create ap0 interface on top of wlan0
iw dev ap0 del 2> /dev/null
iw dev wlan0 interface add ap0 type __ap

# Stop any dnsmasq and hostapd services in case already running
systemctl disable --now hostapd dnsmasq kvmd-otgnet-dnsmasq

sed -i 's#^DAEMON_CONF=.*#DAEMON_CONF=/etc/hostapd/hostapd.conf#' /etc/init.d/hostapd

### Add /var/lib/misc entry in /etc/fstab
# Required for dnsmasq to keep track of leased IPs and logs
if [ $( grep -wc misc /etc/fstab ) -ne 1 ]; then

  cat <<FSTAB >> /etc/fstab
tmpfs /var/lib/misc     tmpfs  mode=0755               0 0
FSTAB

  # mount /var/lib/misc
  mount /var/lib/misc

fi

# Backup original /etc/dnsmasq.conf
if [ ! -e /etc/dnsmas.conf.orig ]; then cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig; fi

### Create custom /etc/dnsmasq.conf file
if [[ $( netstat -nap | grep :53\ | grep -v dnsmasq | wc -l ) -eq 0 ]]; then
  # use dnsmasq default port
  DNSPORT=53
else
  # another dns resolver is listening on port 53, so use different port
  DNSPORT=5553
fi

cat <<DNSMASQ > /etc/dnsmasq.conf
log-facility=/var/lib/misc/dnsmasq.log
dhcp-range=interface:ap0,${NETWORK}.10,${NETWORK}.250,12h
port=${DNSPORT}   # use this to listen for DNS requests
dhcp-option=6,${NAMESERVERS}
log-queries
DNSMASQ

ifconfig ap0 down
ifconfig ap0 up
ifconfig ap0 ${NETWORK}.1/24

### Add firewall rule to allow ap0 routed through current default static route interface ###
iptables -t nat -F
iptables -F

# use the first default static route interface
IFACE=$( ip route | grep default | awk '{print $5}' | head -1 )

iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
iptables -A FORWARD -i ap0 -o $IFACE -j ACCEPT
echo '1' > /proc/sys/net/ipv4/ip_forward

## Add entry in /etc/dhcpcd.conf so that wifi doesn't get a DHCP address
if [ $( grep -wc nohook /etc/dhcpcd.conf ) -ne 1 ]; then

  cat <<DHCPCD >> /etc/dhcpcd.conf
interface ap0
static ip_address=${NETWORK}.1/24
nohook wpa_supplicant
DHCPCD

fi

### Add required routed-ap configuration
if [ ! -e /etc/sysctl.d/routed-ap.conf ]; then

  cat <<ROUTEDAP  > /etc/sysctl.d/routed-ap.conf
# Enable IPv4 routing
net.ipv4.ip_forward=1
ROUTEDAP

fi

### overwrite /etc/hostapd/hostapd.conf config
cat <<EOF > /etc/hostapd/hostapd.conf
country_code=US
interface=ap0
driver=nl80211
channel=1
hw_mode=g
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0

ssid=${SSID}
wpa=2
wpa_passphrase=${PASSPHRASE}

wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
# Change the broadcasted/multicasted keys after this many seconds.
wpa_group_rekey=600
# Change the master key after this many seconds. Master key is used as a basis
wpa_gmk_rekey=86400
EOF

systemctl unmask hostapd
# If -f (force) option is passed in, then enable services to run at boot
if [[ "$1" == "-f" || "$1" == "--firstboot" ]]; then

  rm -f /usr/bin/hotspot-enable
  cat <<SCRIPT > /usr/bin/hotspot-enable
#!/bin/bash
# Script to enable hotspot at anytime
set -x
# Delete and re-create ap0 interface on top of wlan0
iw dev ap0 del 2> /dev/null
iw dev wlan0 interface add ap0 type __ap

ifconfig ap0 down
ifconfig ap0 up
ifconfig ap0 ${NETWORK}.1/24

iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
iptables -A FORWARD -i ap0 -o $IFACE -j ACCEPT
echo '1' > /proc/sys/net/ipv4/ip_forward

systemctl restart hostapd dnsmasq
SCRIPT

  chmod +x /usr/bin/hotspot-enable

  # Create service file to run hotspot-enable script at boot (that runs with -f option)
  rm -f /usr/lib/systemd/system/hotspot.service
  cat <<FWSVC > /usr/lib/systemd/system/hotspot.service
[Unit]
Description=Run Hotspot AP at boot
After=network.target network-online.target nss-lookup.target

[Service]
User=root
Type=simple
ExecStart=/usr/bin/hotspot-enable

[Install]
WantedBy=multi-user.target
FWSVC

  # enable and start hotspot.service to start at boot
  systemctl enable --now hotspot.service hostapd dnsmasq

else

  # disable hotspot.service
  systemctl disable --now hotspot.service

fi

# Restat hostapd and dnsmasq so the config changes take effect
systemctl restart hostapd dnsmasq

### Added on 03/03/22 -- just in case kvmd-otgnet-dnsmasq was already running
# fix it by adding entry for usb0 DHCP
if [ ! -e /usr/bin/otgnet.sh ]; then
  wget -O /usr/bin/otgnet.sh  https://kvmnerds.com/PiKVM/otgnet.sh 2> /dev/null
  chmod +x /usr/bin/otgnet.sh
fi
/usr/bin/otgnet.sh

sleep 3
ip -br a | grep ap0
iwconfig ap0
systemctl status hostapd dnsmasq

if [ -e /usr/local/bin/ro ]; then ro; fi