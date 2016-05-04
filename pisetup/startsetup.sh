#!/bin/bash
# -------------------------------------------------------------
# Auto installation tool for Raspberry Pi to be used on the
# Project MARCH exoskeleton as connection bridge to an external
# monitoring client.

# Script should be executed as root
if [ $(id -u) -ne 0 ]; then
    printf "Please run this script as root. Installing software won't work otherwise\n"
    exit 1
fi

# Notify the user about where to run this script
read -p $'Auto installation tool for Raspberry Pi to be used on the Project MARCH exoskeleton as connection bridge to an external monitoring client.\nDo only run this tool on a designated Raspberry Pi! It might break any other system.\nPress CTRL+C to abort, or ENTER to continue.'

# Warning: internet connection required
read -p $'\n Please make sure the Raspberry Pi is connected to the internet. This tool will automatically download and install required software. In addition, make sure to run this tool on a local terminal or in a screen session. A remote session will be interrupted during network reconfiguration and might break the installation. \nPress ENTER to continue'

printf "Updating software lists...\n"
apt-get -qq update

printf "Upgrading installed software... (this may take quite some time)\n"
apt-get -qq -y upgrade

printf "Installing required software...\n"
apt-get -qq -y install git python dnsmasq hostapd

printf "Downloading configuration files...\n"
git clone https://github.com/ryuutdf/projectmarchcode.git

printf "Temporarily stopping services before configuration...\n"

service hostapd stop
service dnsmasq stop

printf "Executing configuration script...\n"
python projectmarchcode/pisetup/configurator.py

printf "Configuring service for starting on boot...\n"
systemctl enable hostapd
systemctl enable dnsmasq


read -p $'Installation complete.\nPlease disconnect the Raspberry Pi from the current network. Leaving the Raspberry Pi connected will cause malfunctions on the network.\nAfter disconnecting, press ENTER to reboot and activate the configuration.'
