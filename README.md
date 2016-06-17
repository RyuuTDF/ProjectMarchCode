# ProjectMarchCode
Code for the monitoring system

How to use
==============

Setup Local
--------------
- ensure the configuration is set to 'local'
- in SimpleGui.mat, execute SimpleGui.testStream

GUI
--------------

- in order to change certain parameters like the size or update rate, load 'GuiConfig.mat', change the parameter in the config struct and save the changed config to 'GuiConfig.mat'
- in order to toggle updates, select the checkbox in the upper left
- in order to view all sensors, select the checkbox in the upper right

Pisetup
--------------
This folder contains scripts for setting up a freshly installed Raspberry Pi for use in our project. It is desinged in such a manner that only one file is needed for the 
installation to start: startsetup.sh. This script will guide the installation by downloading the other files from Github, installing packeges from the Raspbian repositories, 
configuring all the software and compiling our programs written in C. Apart from configuration files, this directory contains the following programs (in source) and scripts:
 - configurator.py - A tool to help with file modifications during installation
 - startsetup.sh - The installation script as mentioned before
 - forwarder.c - The main program: it will forward data sent by the simulink model on the ethernet interface to the GUI on the other side on the wireless interface
 - reference.c - Program to re-send the first (reference) packet to a client that stepped in later
 - statuscli.py - Script displaying some statistics on a display (when not running headless)
 - recorder.c - A tool to store received packets in a binary recording file
 - convert.c - Converts the binary file generatesd by the recorder to a more readable tab separated file
 - http.py - A very basic webserver that lists recordings and provides download functionality for converted recording files

Flags used during compilation of the C programs: -lz (forwarder.c and convert.c) -D_BSD_SOURCE -Wall -std=c11
