#!/bin/bash

# Configuration =======================================================================================================

SSID="$HOSTNAME"                # Defaults SSID to hostname
DHCP_START="10.10.10.2"         # Start of DHCP IP pool
DHCP_END="10.10.10.254"         # End of DHCP IP pool

# End of Configuration ================================================================================================

DISABLE=false
FAILOVER=""
PASSWORD=""
QUIET=false
SCRIPT="$(basename $0)"

show_help() {
    cat <<EOF
Usage: $SCRIPT [OPTIONS]

Options:
  -d, --disable             Turn off access point
  -f, --failover            Automatically turn on/off on network disconnect/connect
  --failover=false          Disable automatic on/off on disconnect/connect
  -h, --help                Show this help message
  -q, --quiet               Run without output
  --ssid SSID               The SSID for the access point
  --passwd PASSWORD         The password for the access point
EOF
}

is_connected() {
    [ -n "$(iwgetid -r)" ]
}

is_on() {
    [ "$(systemctl is-active hostapd)" == "active" ]
}

enable_ap() {
    if is_on; then
        log_message "Access point is already on"
        exit
    fi
    log_message "Turning on access point: $SSID"
    systemctl stop dhcpcd
    systemctl stop wpa_supplicant
    systemctl stop systemd-resolved
    ip link set wlan0 down
    ip link set wlan0 up
    ip addr add "$DHCP_IP/24" dev wlan0

    # Configure and start hostapd
    cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0
ssid=$SSID
hw_mode=g
channel=4
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
interface=wlan0
dhcp-range=$DHCP_START,$DHCP_END,255.255.255.0,24h
EOF
    systemctl start dnsmasq
}

disable_ap() {
    if ! is_on; then
        log_message "Access point is already off"
        exit
    fi
    log_message "Turning off access point..."
    ip addr del "$DHCP_IP/24" dev wlan0
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
    echo "* * * * *     root    $(realpath $0) --ssid '$SSID' --passwd '$PASSWORD' -q -f" >> /etc/crontab
    echo "Access point failover enabled"
}

disable_cron() {
    sed -i "/$SCRIPT/d" /etc/crontab
    echo "Access point failover disabled"
}

log_message() {
    if [ "$QUIET" != "true" ]; then
        echo "$1"
    fi
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--disable) DISABLE=true ;;
        -f|--failover) FAILOVER=true ;;
        --failover=false) FAILOVER=false ;;
        -h|--help) show_help && exit ;;
        -q|--quiet) QUIET=true ;;
        --ssid)  shift && SSID="$1" ;;
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

if [ -n "$FAILOVER" ]; then
    if [ "$FAILOVER" == "false" ]; then
        disable_cron
        exit
    fi

    if [ -z "$(grep "$SCRIPT" /etc/crontab)" ]; then
        if [ -z "$PASSWORD" ]; then
            echo "Error: Password required"
            show_help
            exit 1
        fi
        enable_cron
    fi

    if is_connected; then
        DISABLE=true
    fi
fi

if [ "$DISABLE" == "true" ]; then
    disable_ap
else
    if [ -z "$PASSWORD" ]; then
        echo "Error: Password required"
        show_help
        exit 1
    fi
    enable_ap
fi
