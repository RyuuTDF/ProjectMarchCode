#!/usr/bin/python
# -------------------------------------------------------------
# Forwards packages received on one interface to the other

import socket

def send(data, port=25000, addr='192.168.20.255'):
	"""send(data[, port[, addr]]) - multicasts a UDP datagram."""
	# Create the socket
	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	# Make the socket multicast-aware, and set TTL.
	s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 20) # Change TTL (=20) to suit
	# Send the data
	s.sendto(data, (addr, port))

def recvLoop():
	UDP_IP = "192.168.21.0"
	UDP_PORT = 25000

	sock = socket.socket(socket.AF_INET, # Internet
		socket.SOCK_DGRAM) # UDP
	sock.bind((UDP_IP, UDP_PORT))

	while True:
		data, addr = sock.recvfrom(65507) # buffer size is 65507 bytes
		send(data)
	sock.close()

if __name__ == "__main__":
	recvLoop()
