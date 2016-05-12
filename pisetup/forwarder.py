#!/usr/bin/python
# -------------------------------------------------------------
# Forwards packages received on one interface to the other

import socket
import time
import array
import ctypes
import mmap
import os
import struct

def send(data, port=25000, addr='192.168.20.255'):
	"""send(data[, port[, addr]]) - multicasts a UDP datagram."""
	# Create the socket
	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	
	s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
	# Send the data
	s.sendto(data, (addr, port))

def receiveLoop(rateVar, connectedVar):
	UDP_IP = "192.168.21.1"
	UDP_PORT = 25000
	
	sock = socket.socket(socket.AF_INET, # Internet
		socket.SOCK_DGRAM) # UDP
	sock.bind((UDP_IP, UDP_PORT))
	connectedVar.value = 1
	times = array.array('d')
	while True:
		data, addr = sock.recvfrom(65507) # buffer size is 65507 bytes
		send(data)
		times.append(time.time())
		if len(times) == 50:
			d = times[49] - times[0]
			times = []
			rateVar.value = 50/d
	sock.close()

if __name__ == "__main__":
	# Create new empty file to back memory map on disk
	fd = os.open('/run/exoshm', os.O_CREAT | os.O_TRUNC | os.O_RDWR)
	
	# Zero out the file to insure it's the right size
	assert os.write(fd, '\x00' * mmap.PAGESIZE) == mmap.PAGESIZE
	
	# Create the mmap instace with the following params:
	# fd: File descriptor which backs the mapping or -1 for anonymous mapping
	# length: Must in multiples of PAGESIZE (usually 4 KB)
	# flags: MAP_SHARED means other processes can share this mmap
	# prot: PROT_WRITE means this process can write to this mmap
	buf = mmap.mmap(fd, mmap.PAGESIZE, mmap.MAP_SHARED, mmap.PROT_WRITE)
	
	# Now create an int in the memory mapping
	connected = ctypes.c_int.from_buffer(buf)
	connected.value = 0
	
	# Before we create a new value, we need to find the offset of the next free
	# memory address within the mmap
	offset = struct.calcsize(connected._type_)
	packetRate = ctypes.c_double.from_buffer(buf, offset)
	packetRate.value = 0
	
	while True:
		try:
			receiveLoop(packetRate, connected)
		except socket.error:
			print "No network. Retry in 10 seconds"
			connected.value = 0
			packetRate.value = 0
			time.sleep(10)
