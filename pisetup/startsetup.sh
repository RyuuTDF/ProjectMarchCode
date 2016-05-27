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
apt-get -qq -y install git python dnsmasq hostapd python-pip gcc zlib1g-dev
pip install flask -q
pip install tabulate -q

printf "Downloading configuration files...\n"
git clone https://github.com/ryuutdf/projectmarchcode.git

printf "Temporarily stopping services before configuration...\n"

service hostapd stop
service dnsmasq stop

printf "Compiling bridge software...\n"

gcc projectmarchcode/pisetup/forwarder.c -o projectmarchcode/pisetup/forwarder -std=c11 -lz -D_BSD_SOURCE -Wall
gcc projectmarchcode/pisetup/reference.c -o projectmarchcode/pisetup/reference -std=c11 -D_BSD_SOURCE -Wall

printf "Executing configuration script...\n"
python projectmarchcode/pisetup/configurator.py

printf "Configuring service for starting on boot...\n"
chmod +x /opt/exo/forwarder
chmod +x /opt/exo/reference
chmod +x /home/pi/statuscli.py
chown pi:pi /home/pi/statuscli.py
systemctl enable hostapd
systemctl enable dnsmasq
systemctl enable forwarder
systemctl enable reference

# Next part is based on raspi-config (except thee last two lines)

printf "Setting boot mode to console...\n"
if command -v systemctl > /dev/null && systemctl | grep -q '\-\.mount'; then
	SYSTEMD=1
elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
	SYSTEMD=0
else
	echo "Unrecognised init system"
fi
if [ $SYSTEMD -eq 1 ]; then
	systemctl set-default multi-user.target
	ln -fs /etc/systemd/system/autologin@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
else
	[ -e /etc/init.d/lightdm ] && update-rc.d lightdm disable 2
	sed /etc/inittab -i -e "s/1:2345:respawn:\/sbin\/getty --noclear 38400 tty1/1:2345:respawn:\/bin\/login -f pi tty1 <\/dev\/tty1 >\/dev\/tty1 2>&1/"
fi
read -p $'Installation complete.\nPlease disconnect the Raspberry Pi from the current network. Leaving the Raspberry Pi connected will cause malfunctions on the network.\nAfter disconnecting, press ENTER to reboot and activate the configuration.'
reboot
