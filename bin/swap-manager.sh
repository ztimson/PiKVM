#!/bin/bash

SCRIPT="$(basename $0)"
SIZE="1024"

show_help() {
    cat <<EOF
Usage: $SCRIPT [OPTION] [SIZE]
Manage swap space on Arch Linux

Options:
  -h, --help       Show this help message and exit
  --disable        Remove the swap file
  SIZE             Size of the swap file in MB (default: 1024)

Examples:
  $SCRIPT 2048           Create a 2GB swap file
  $SCRIPT --disable      Remove the existing swap file
EOF
}

disable_swap() {
  if [ -e /swapfile ]; then
    swapoff /swapfile
    rm -f /swapfile
    echo "SWAP removed"
  else
    echo "SWAP doesn't exist"
  fi
}

enable_swap() {
  if [ -e /swapfile ]; then
     echo "Error: SWAP already exists"
     exit 1
  fi
  echo "Creating SWAP..."
  dd if=/dev/zero of=/swapfile bs=1M count="$SIZE"
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "$SIZE MB SWAP created"
}

# Parse command-line arguments
if [[ "$1" == "--disable" ]]; then
  disable_swap
  exit 0
elif [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  show_help
  exit 0
fi
if [ -n "$1" ]; then SIZE="$1"; fi
enable_swap
