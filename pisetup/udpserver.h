/*
 * udpserver.h
 *
 *  Created on: 15 Jun 2016
 *      Author: ruben
 */

#ifndef UDPSERVER_H_
#define UDPSERVER_H_

#include <arpa/inet.h>
#include <sys/socket.h>
#include <string.h> //memset

void siFormat(struct sockaddr_in* si, const char* address, const short port){
	memset((char *) si, 0, sizeof(*si));
	si->sin_family = AF_INET;
	si->sin_port = htons(port);
	if (inet_aton(address, &si->sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}
}

int openUdpListener(const char* address, const short port){
	int s_in;
	struct sockaddr_in si_me;
	//create a UDP listening socket
	if ((s_in = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("Socket initialisation failed.\n");
	}
	siFormat(&si_me, address, port);

	//bind socket to port
	while (bind(s_in, (struct sockaddr*) &si_me, sizeof(si_me)) == -1) {
		printf("Network not ready (yet). Retrying in 10 seconds\n");
		sleep(10);
	}
	return s_in;
}

int openUdpSender(const int broadcast){
	int socket_out;
	if ((socket_out = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("socket (out)");
	}
	if(broadcast){
		setsockopt(socket_out, SOL_SOCKET, SO_BROADCAST, &broadcast,
				sizeof(broadcast));
	}
	return socket_out;
}


#endif /* UDPSERVER_H_ */
