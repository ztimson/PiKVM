# PiKVM - Pi Zero 2 W

The official PiKVM is expensive so I decided take build my own & add some features in the process:
- Small "USB dongle" form-factor with minimal connections 
- Simple install script which lets you toggle all added features
- Static MAC addresses to fix IP changes on reboot while using DHCP
- Creates access point when network connection is lost for easy configuration
- Ethernet connection for wired networks
  - Ethernet passthrough coming soon!
- E-ink display for showing network information
- Create a jumpbox by adding a wireguard config (`wg0.conf`) to the boot partion
- Simple SWAP managment script to add/remove memory on the fly
  - Install 1G of memory: `swap.sh 1024`
  - Uninstall swap: `swap.sh --disable`

## Hardware
 - [Pi Zero 2 W + SD Card](https://www.raspberrypi.com/products/raspberry-pi-zero-2-w/)
 - [Ethernet to SPI](https://www.waveshare.com/enc28j60-ethernet-board.htm)
 - [HDMI to CSI-2](https://www.waveshare.com/hdmi-to-csi-adapter.htm)
 - [2.13" E-Ink Display](https://www.waveshare.com/2.13inch-e-paper-hat.htm)

## Assembly
1. Cut the head off a USB cable & solder it to the debug pads on the back of the Pi; extend to the right (Opposite the SD card)
2. Connect HDMI/CSI-2 module via short ribbon cable (~40 mm); fold over and glue to back of board alighting with the SD card
3. Wire the Ethernet/SPI module onto SPI chanel 0
4. Connect E-Ink display via side pins to SPI channel 1

## Install
1. Flash SD card with [latest PiKVM image](https://pikvm.org/download/) using the [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Edit `/boot/config.txt` to include:
```
dtoverlay=spi=on
```
3. Edit `/boot/pikvm.txt` to include your WiFi credentials for initial configuration:
```
FIRST_BOOT=1
WIFI_ESSID="wifi_name"
WIFI_PASSWD="wifi_pass"
```
4. Insert SD card into Pi, connect an HDMI cable to the PI HDMI output (not the added module), connect the USB port to power
5. After statup, open the IP address displayed in your browser & use `admin/admin` to login
6. Open the console, login as root & run the install script:
```
$ su -
**Enter password: root**
# curl https://git.zakscode.com/ztimson/PiKVM/raw/branch/master/install.sh | bash
