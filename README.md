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
- Simple SWAP managment script to _download_ more memory on the fly
  - Install 1G of memory: `swap.sh 1024`
  - Uninstall swap: `swap.sh --disable`

## Hardware
 - [Pi Zero 2 W + SD Card](https://www.raspberrypi.com/products/raspberry-pi-zero-2-w/)
 - Ethernet to SPI
   - W5500 (Faster)
   - or [ENC28J60](https://www.waveshare.com/enc28j60-ethernet-board.htm)
 - [HDMI to CSI-2](https://www.waveshare.com/hdmi-to-csi-adapter.htm)
 - [2.13" E-Ink Display](https://www.waveshare.com/2.13inch-e-paper-hat.htm)

## Assembly
1. Cut the head off a USB cable & solder it to the debug pads on the back of the Pi; extend to the right (Opposite the SD card)
2. Connect HDMI/CSI-2 module via short ribbon cable (~40 mm); fold over and glue to back of board alighting with the SD card
3. Wire the Ethernet/SPI module onto SPI chanel 0

| Module | RPI GPIO (Board) |
|--------|------------------|
| V      | 17 (5/3.3 V)     |
| G      | 20 (Any Ground)  |
| MI     | 19 (SPI0 MOSI)   |
| MO     | 21 (SPI0 MISO)   |
| SCK    | 23 (SPI0 SCLK)   |
| CS     | 24 (SPI0 CE0)    |
| INT    | 22 (GPIO 25)     |

4. Connect E-Ink display via side pins to SPI channel 1

| Module | RPI GPIO (Board) |
|--------|------------------|
| VCC    | 4  (5/3.3 V)     |
| GND    | 6 (Any Ground)   |
| DIN    | 19 (SPI0 MOSI)   |
| CLK    | 23 (SPI0 SCLK)   |
| CS     | 26 (SPI0 CE1)    |
| DC     | 15 (GPIO 22)     |
| RST    | 16 (GPIO 23)     |
| BUSY   | 18 (GPIO 24)     |

## Build PiKVM

To use ethernet over SPI, you will need to build your own version of PiKVM by doing the following:

1. Install tools: `sudo apt install git make curl binutils docker.io -y`
2. Clone sources: `git clone --depth=1 https://github.com/pikvm/os`
3. Create the following file `config.mk`:
```
# Base board
BOARD = zero2w

# Hardware configuration
PLATFORM = v2-hdmi

# Target hostname
HOSTNAME = pikvm

# ru_RU, etc. UTF-8 only
LOCALE = en_US

# See /usr/share/zoneinfo
TIMEZONE = UTC

# For SSH root user
ROOT_PASSWD = root

# Web UI credentials: user=admin, password=adminpass
WEBUI_ADMIN_PASSWD = admin

# IPMI credentials: user=admin, password=adminpass
IPMI_ADMIN_PASSWD = admin
```
4. Make the OS: `sudo make os NC=1`
5. Make image: `sudo make image`
6. Use the created image inside `images/` in the next step

## Install
1. Flash SD card with your built image or the [latest PiKVM image](https://pikvm.org/download/) using the [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Open the newly created boot directory on the SD card in your file browser
3. Enable SSH by creating an empty file: `/boot/ssh`
4. Edit `/boot/config.txt` to include:
```
# For screen and/or ethernet:
dtparam=spi=on

# Pick correct ethernet chip:
dtoverlay=w5500
# Or
dtoverlay=enc28j60
```
5. Edit `/boot/pikvm.txt` to include your WiFi credentials for initial configuration:
```
FIRST_BOOT=1
WIFI_ESSID="wifi_name"
WIFI_PASSWD="wifi_pass"
```
6. Insert SD card into Pi, connect an HDMI cable to the PI HDMI output (not the added module), connect the USB port to power
7. After statup, open the IP address in your browser or SSH directly & use `admin/admin` to login
8. Open the console, login as root & run the install script:
```
$ su -
**Enter password: root**
# curl https://git.zakscode.com/ztimson/PiKVM/raw/branch/master/install.sh | bash
```

## TODO:
[USB Storage](https://docs.pikvm.org/msd/#manual-images-uploading)
[Ethernet Passthrough](https://docs.pikvm.org/usb_ethernet/)