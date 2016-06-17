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
#include "udpserver.h"

//TODO: Move some of these constants to a config file
#define SERVER "0.0.0.0"
#define TMP_DIR "/run/"
#define BUFLEN 65507  //Max length of buffer
#define PORT_IN 25001   //The port on which to receive requests
#define PORT_OUT 25000   //The port on which to send data

/** 
 * sendReference: send a reference packet to a client who requested one
 */
void sendReference(short chk, struct sockaddr_in si_out, struct SharedMemory* sharedMemory, int socket){
	unsigned char compressed[BUFLEN];
	if(chk != sharedMemory->referenceLength){
		printf("Request for sequence not in use by forwarder\n");
		return;
	}
	//Check existence of a stored packet
	char filename[sizeof(char) * strlen(TMP_DIR) + 5];
	sprintf(filename, "%s%x", TMP_DIR, chk);
	printf("Request from %s for file %s\n", inet_ntoa(si_out.sin_addr), filename);
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

/**
 * startRecording: Prepare the system for recording
 */
void startRecording(SharedMemory* sharedMemory, long int startTime){
	//Make sure that there is not an already running recording
	if((sharedMemory->recordingState & RECORDING_RUNNING) != RECORDING_RUNNING){
		sharedMemory->recordingState = (sharedMemory->recordingState | RECORDING_WANTED);
		sharedMemory->recorderStartTime = startTime;
		//Execute recorder tool in separate process
		if(fork() == 0){
			execl("/opt/exo/recorder", "/opt/exo/recorder", NULL);
			exit(0);
		}
	}
}

int main(int argc, char *argv[]) {
	//Declaration of variables
	int socket_in, socket_out, recv_len, mmapFile;
	struct sockaddr_in si_other, si_out;
	struct SharedMemory* sharedMemory;
	unsigned short cmd;
	unsigned char buffer[BUFLEN];
	unsigned int si_len = sizeof(si_other);
	socket_in = openUdpListener(SERVER, PORT_IN);
	socket_out = openUdpSender(0);
	//Partially initialise the address structure for replies
	memset((char *) &si_out, 0, sizeof(si_out));
	si_out.sin_family = AF_INET;
	si_out.sin_port = htons(PORT_OUT);
	openShm(&mmapFile, &sharedMemory, PROT_READ | PROT_WRITE, O_RDWR);
	sharedMemory->softwareState = (sharedMemory->softwareState | SW_REFERENCE);

	//keep listening for data
	while (1) {
		//try to receive some data, this is a blocking call
		if ((recv_len = recvfrom(socket_in, buffer, BUFLEN, 0,
				(struct sockaddr *) &si_other, &si_len)) == -1) {
			sharedMemory->softwareState = sharedMemory->softwareState & !SW_REFERENCE;
			die("Receiving data failed.\n");
		}
		//Multiple commands possible, cmd will contain the requested action
		memcpy(&cmd, buffer, 2);
		printf("cmd: %i\n", cmd);
		if(cmd == 1){
			//Send reference packet
			unsigned short chk;
			memcpy(&chk, buffer + 2, 2);
			si_out.sin_addr = si_other.sin_addr;
			sendReference(chk, si_out, sharedMemory, socket_out);
		}else if(cmd == 2){
			//Start recording
			long int startTime;
			memcpy(&startTime, buffer + 2, 4);
			startRecording(sharedMemory, startTime);
		}else if(cmd == 3){
			//Stop recording. The recorder service will get the changed state in its main loop
			sharedMemory->recordingState = (sharedMemory->recordingState & !RECORDING_WANTED);
		}else{
			printf("Request for unknown command %i", cmd);
		}

	}
	close(mmapFile);
	shutdown(socket_out, SHUT_RDWR);
	shutdown(socket_in, SHUT_RDWR);
}
