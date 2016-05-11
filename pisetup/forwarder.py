#!/usr/bin/python
# -------------------------------------------------------------
# Forwards packages received on one interface to the other

import socket
import time
import array

def send(data, port=25000, addr='192.168.20.255'):
	"""send(data[, port[, addr]]) - multicasts a UDP datagram."""
	# Create the socket
	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
	s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
	# Make the socket multicast-aware, and set TTL.
	#s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 20) # Change TTL (=20) to suit
	# Send the data
	s.sendto(data, (addr, port))

def recvLoop():
	UDP_IP = "192.168.21.1"
	UDP_PORT = 25000

	sock = socket.socket(socket.AF_INET, # Internet
		socket.SOCK_DGRAM) # UDP
	sock.bind((UDP_IP, UDP_PORT))
	times = array.array('d')
	while True:
		data, addr = sock.recvfrom(65507) # buffer size is 65507 bytes
		send(data)
		times.append(time.time())
		if len(times) == 50:
			d = times[49] - times[0]
			times = []
			print("Packet rate: %2f" % (50/d))
	sock.close()

if __name__ == "__main__":
	while True:
		try:
			recvLoop()
		except socket.error:
			print "No network. Retry in 10 seconds"
			time.sleep(10)
