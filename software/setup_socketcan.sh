#!/bin/bash

# Load kernel modules and setup can0 network interface,
# configured for 1Mbit bit rate.
# Assumes that a PEAK CAN to USB adapter is connected
# (might work with similar devices compatible with socketcan)

sudo modprobe can
sudo modprobe can_raw
sudo modprobe can_bcm
sudo ip link set can0 type can bitrate 1000000
sudo ifconfig can0 up
