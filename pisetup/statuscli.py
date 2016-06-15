#!/usr/bin/python

import mmap
import os
import struct
import time
import sys
from tabulate import tabulate
import curses
import subprocess

def main(stdscr):
	# Open the file for reading
	fd = os.open('/run/exoshm', os.O_RDONLY)
	
	# Memory map the file
	buf = mmap.mmap(fd, mmap.PAGESIZE, mmap.MAP_SHARED, mmap.PROT_READ)
	
	connected = None
	packetRate = None
	simulationTime = None
	recording = None
	software = None
	while 1:
		new_c, = struct.unpack('i', buf[:4])
		new_p, = struct.unpack('d', buf[4:12])
		new_t, = struct.unpack('d', buf[12:20])
		new_r, = struct.unpack('h', buf[22:24])
		new_s, = struct.unpack('h', buf[24:26])
		
		# Only update when new data is present
		if connected != new_c or packetRate != new_p or new_t != simulationTime or software != new_s or recording != new_t :
			# Add a temperature readout to the data
			p = subprocess.Popen(['/opt/vc/bin/vcgencmd', 'measure_temp'], stdout=subprocess.PIPE, 
			stderr=subprocess.PIPE)
			out, err = p.communicate()
			# Display the statistics in a table on the screen
			text = tabulate([[new_c, new_p, new_t, out[5:], new_s, new_r]], headers=['Connected','Packets/s', 'Sim time', 'Temperature', 'Software', 'Recorder'])
			stdscr.addstr(0, 0, text)
			stdscr.refresh()
			recording = new_t
			software= new_s
			connected = new_c
			packetRate = new_p
			simulationTime = new_t
		
		# Prevent the interface from consuming too much CPU
		time.sleep(0.1)


if __name__ == '__main__':
	curses.wrapper(main)
