#!/usr/bin/python

import mmap
import os
import struct
import time
import sys
from tabulate import tabulate
import curses
import subprocess

def main():
	# Open the file for reading
	fd = os.open('/run/exoshm', os.O_RDONLY)
	
	# Memory map the file
	buf = mmap.mmap(fd, mmap.PAGESIZE, mmap.MAP_SHARED, mmap.PROT_READ)
	
	connected = None
	packetRate = None
	stdscr = curses.initscr()
	
	while 1:
		new_c, = struct.unpack('i', buf[:4])
		new_p, = struct.unpack('f', buf[4:8])
		
		if connected != new_c or packetRate != new_p:
			p = subprocess.Popen(['/opt/vc/bin/vcgencmd', 'measure_temp'], stdout=subprocess.PIPE, 
			stderr=subprocess.PIPE)
			out, err = p.communicate()
			text = tabulate([[new_c, new_p, out[5:]]], headers=['Connected','Packets/s', 'Temperature'])
			stdscr.addstr(0, 0, text)
			stdscr.refresh()
			connected = new_c
			packetRate = new_p
			
			time.sleep(1)


if __name__ == '__main__':
	main()
