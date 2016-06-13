/*
 * recorder.c
 *
 *  Created on: 9 Jun 2016
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
#include <sys/stat.h>//mkfifo
#include "shared.h"

#define REFERENCE "127.0.0.1"
#define SERVER "192.168.20.1"
#define PORT_IN 25000
#define PORT_OUT 25001
#define BUFLEN 65507  //Max length of buffer
#define RECORDING_DIR "/home/pi/recordings/"

void requestReference(short chk){
	int socket_out;
	struct sockaddr_in si_out, si_me;
	//Setup socket for sending data
	if ((socket_out = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("socket (out)");
	}


	memset((char *) &si_out, 0, sizeof(si_out));
	si_out.sin_family = AF_INET;
	si_out.sin_port = htons(PORT_OUT);
	memset((char *) &si_me, 0, sizeof(si_me));
	si_me.sin_family = AF_INET;
	si_me.sin_port = 0;
	if (inet_aton(REFERENCE, &si_out.sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}

	if (inet_aton(SERVER, &si_me.sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}
	if(bind(socket_out, (struct sockaddr*) &si_me, sizeof(si_me)) == -1){
		printf("Could not bind to correct network...\n");
	}
	char packet[3];
	packet[0] = 1;
	memcpy(packet + 1, &chk, 2);
	if(sendto(socket_out, packet, 3, 0,
					(struct sockaddr *) &si_out, sizeof(si_out)) == -1){
		perror("Socket send");
	}
	sleep(1);
	shutdown(socket_out, SHUT_RDWR);

}

int main(int argc, char *argv[]) {
	//At first, open the shared memory. Details on the recording request can be found there
	struct SharedMemory* sharedMemory;
	int mfd;
	openShm(&mfd, &sharedMemory, PROT_WRITE | PROT_READ, O_RDWR);
	if (sharedMemory == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	if((sharedMemory->recordingState & RECORDING_WANTED) != RECORDING_WANTED){
		printf("Recorder started without request. Confused....\n");
		return 1;
	}
	//Forwarder is the only program that will create the shared memory.
	sharedMemory->softwareState = sharedMemory->softwareState | SW_RECORDER;
	//Variable definitions
	int socket_in, recv_len;
	unsigned char buf[BUFLEN];

	char fileNamePart[32];
	struct tm time;
	localtime_r(&sharedMemory->recorderStartTime, &time);
	strftime(fileNamePart, 32, "%Y%m%d%H%M%S.rec", &time);
	char filename[64];
	sprintf(filename, "%s%s", RECORDING_DIR, fileNamePart);
	int fd = open(filename, O_RDWR | O_CREAT);
	//Wait for the forwarder making preparations for the recording
	char pipename[sizeof(char) * strlen(TMP_DIR) + 5];
	sprintf(pipename, "%s%x", TMP_DIR, sharedMemory->recorderStartTime);
	printf("Creating pipe...\n");
	mkfifo(pipename, 0600);
	sharedMemory->recordingState = (sharedMemory->recordingState | RECORDING_STOPPED);
	printf("Opening pipe for reading (this will block)\n");
	int pipe = open(pipename, O_RDONLY);//BLOCKING call!
	printf("Recording :)\n");
	//Receive loop
	while ((sharedMemory->recordingState != RECORDING_STOPPED) && (sharedMemory->recordingState!=0)) {

		//try to receive some data, this is a blocking call
		if ((recv_len = read(pipe, buf, BUFLEN)) == -1) {
			die("Receiving data failed.\n");
		}
		printf("Writing %d bytes\n", recv_len);
		write(fd, buf, recv_len);
	}
	if(sharedMemory->recordingState!=0){
		printf("Recording finished\n");
	}else{
		printf("Recording stopped, state was unexpected!\n");
	}
	close(fd);
	close(pipe);
	sharedMemory->recordingState = 0;
	close(mfd);
	return 0;
}
