#!/bin/bash

# Configuration =======================================================================================================

SSID="$(hostname)"              # Access point SSID name
PASSWORD="guesswhatitis"        # Access point password
DHCP_IP="10.10.10.1"            # Device IP on access point
DHCP_START="10.10.10.2"         # Start of DHCP IP pool
DHCP_END="10.10.10.254"         # End of DHCP IP pool

# End of Configuration ================================================================================================

SCRIPT="$(basename $0)"
QUIET=false
FAILOVER=""

show_help() {
    echo "Usage: $(basename $0) [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --failover        Automaticaly toggle AP when network connection is lost"
    echo "  --failover=false      Disable automatic toggling of AP"
    echo "  -h, --help            Show this help message"
    echo "  -q, --quiet           Run without output"
    echo "  --ssid <SSID>         Override default SSID"
    echo "  --passwd <PASSWORD>   Override default password"
}

is_active() {
    [ "$(systemctl is-active hostapd)" == "active" ]
}

is_connected() {
    [ -n "$(iwgetid -r)" ] 
}

enable_ap() {
    log_message "Enabling AP..."
    systemctl stop dhcpcd
    systemctl stop wpa_supplicant
    systemctl stop systemd-resolved

    ip link set wlan0 down
    ip link add link wlan0 name ap0 type macvlan mode bridge
    ip link set ap0 up
    ip addr add "$DHCP_IP/24" dev ap0

    # Configure and start hostapd
    cat <<EOF > /etc/hostapd/hostapd.conf
interface=ap0
ssid=$SSID
hw_mode=g
channel=0
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
    systemctl unmask hostapd
    systemctl start hostapd

    # Configure and start dnsmasq
    cat <<EOF > /etc/dnsmasq.conf
interface=ap0
dhcp-range=$DHCP_START,$DHCP_END,255.255.255.0,24h
EOF
    systemctl start dnsmasq
}

disable_ap() {
    log_message "Disabling AP..."
    ip addr del "$DHCP_IP/24" dev ap0
    ip link set ap0 down
    ip link delete ap0
    systemctl stop hostapd
    systemctl stop dnsmasq
    systemctl start systemd-resolved
    systemctl restart dhcpcd
}

enable_cron() {
    if [ -z "$(which crontab)" ]; then
        echo "Error: Please install crontab"
        exit 1
    fi
    sed -i "/$SCRIPT/d" /etc/crontab
    echo "* * * * *     root    $(realpath $0) -q" >> /etc/crontab
    echo "Automatic fallback AP enabled"
}

disable_cron() {
    sed -i "/$SCRIPT/d" /etc/crontab
    echo "Automatic fallback AP disabled"
}

log_message() {
    if [ "$QUIET" != "true" ]; then
        echo "$1"
    fi
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--failover|--failover=true) FAILOVER=true ;;
        --failover=false) FAILOVER=false ;;
        -h|--help) show_help && exit ;;
        -q|--quiet) QUIET=true ;;
        --ssid) shift && SSID="$1" ;;
        --passwd) shift && PASSWORD="$1" ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

# Check for permissions
if [ "$UID" != "0" ]; then
    echo "Error: Please run as root"
    exit 1
fi

# Check if connected to WiFi
if [ "$FORCE" == "false" ] && is_connected; then
    log_message "Already connected to WiFi"
    # Disable the access point if it's running
    if [ "$(systemctl is-active hostapd)" == "active" ]; then
        disable_ap
    fi
elif ! is_active; then
    if [ "$FORCE" == "true" ]; then disable_cron; fi
    enable_ap
fi
