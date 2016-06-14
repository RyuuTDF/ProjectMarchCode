/*
 * reference.c
 *
 * Service that waits for requests for a reference packet, and will
 * try to send the requested packet back to the client
 *
 *  Created on: 26 May 2016
 *      Author: ruben
 */
#include <stdio.h> //printf
#include <string.h> //memset
#include <stdlib.h> //exit(0);
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include "shared.h"

//TODO: Move some of these constants to a config file
#define SERVER "0.0.0.0"
#define TMP_DIR "/run/"
#define BUFLEN 65507  //Max length of buffer
#define PORT_IN 25001   //The port on which to receive requests
#define PORT_OUT 25000   //The port on which to send data

void sendReference(short chk, struct sockaddr_in si_out, struct SharedMemory* sharedMemory, int socket){
	unsigned char compressed[BUFLEN];
	if(chk != sharedMemory->referenceLength){
		printf("Request for sequence not in use by forwarder\n");
		return;
	}
	//Check existence of a stored packet
	char filename[sizeof(char) * strlen(TMP_DIR) + 5];
	sprintf(filename, "%s%x", TMP_DIR, chk);
	printf("Request from %x for file %s\n", si_out.sin_addr, filename);
	if (access(filename, R_OK) != -1) {
		//Requested packet is stored, so read it...
		int fd = open(filename, O_RDONLY);
		if (fd == -1) {
			printf("Accessing file failed!\n");
			return;
		}
		int packedSize = read(fd, compressed, BUFLEN);
		close(fd);
		//... and send it back to the client
		if (sendto(socket, compressed, packedSize, 0,
				(struct sockaddr *) &si_out, sizeof(si_out)) == -1) {
			printf("Package lost...\n");
			//Package lost... Well, ignore for now... Client should request a new one anyway
		}
	} else {
		printf("Request for unknown packet %x\n", chk);
	}
}

int main(int argc, char *argv[]) {
	//Declaration of variables
	struct sockaddr_in si_me, si_other, si_out;
	int s_in, s_out, recv_len;
	struct SharedMemory* sharedMemory;
	unsigned int slen = sizeof(si_other);
	unsigned char buf[BUFLEN];
	//create a UDP listening socket
	if ((s_in = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("Socket initialisation failed.\n");
	}

	// zero out the structure
	memset((char *) &si_me, 0, sizeof(si_me));

	si_me.sin_family = AF_INET;
	si_me.sin_port = htons(PORT_IN);
	if (inet_aton(SERVER, &si_me.sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}

	//bind socket to port
	while (bind(s_in, (struct sockaddr*) &si_me, sizeof(si_me)) == -1) {
		printf("Network not ready (yet). Retrying in 10 seconds\n");
		sleep(10);
	}

	//Setup of the socket for sending responses
	if ((s_out = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("socket (out)");
	}
	//Partially initialise the address structure for replies
	memset((char *) &si_out, 0, sizeof(si_out));
	si_out.sin_family = AF_INET;
	si_out.sin_port = htons(PORT_OUT);
	int mfd;
	openShm(&mfd, &sharedMemory, PROT_READ | PROT_WRITE, O_RDWR);
	sharedMemory->softwareState = (sharedMemory->softwareState | SW_REFERENCE);

	//keep listening for data
	while (1) {
		//try to receive some data, this is a blocking call
		if ((recv_len = recvfrom(s_in, buf, BUFLEN, 0,
				(struct sockaddr *) &si_other, &slen)) == -1) {
			sharedMemory->softwareState = sharedMemory->softwareState & !SW_REFERENCE;
			die("Receiving data failed.\n");
		}

		si_out.sin_addr = si_other.sin_addr;
		//Multiple commands possible, cmd will contain the requested action
		unsigned short cmd;
		memcpy(&cmd, buf, 2);

		if(cmd == 1){
			//Send reference packet
			unsigned short chk;
			memcpy(&chk, buf + 2, 2);
			sendReference(chk, si_out, sharedMemory, s_out);
		}else if(cmd == 2){
			//Start recording
			if((sharedMemory->recordingState & RECORDING_RUNNING) != RECORDING_RUNNING){
				sharedMemory->recordingState = (sharedMemory->recordingState | RECORDING_WANTED);
				memcpy(&sharedMemory->recorderStartTime, buf + 2, 4);
				//execvp("service", ("service", "recorder", "start", NULL));
				//TODO: start recorder service
			}

		}else if(cmd == 3){
			//Stop recording. The recorder service will get the changed state in its main loop
			sharedMemory->recordingState = (sharedMemory->recordingState & !RECORDING_WANTED);
		}else{
			printf("Request for unknown command %h", cmd);
		}
	}
	close(mfd);
	shutdown(s_out, SHUT_RDWR);
	shutdown(s_in, SHUT_RDWR);
}
