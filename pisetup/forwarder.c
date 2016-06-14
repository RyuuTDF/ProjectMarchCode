/*
 * forwarder.c
 *
 *  Created on: 25 May 2016
 *      Author: ruben
 */

#include <stdio.h> //printf
#include <string.h> //memset
#include <stdlib.h> //exit(0);
#include <fcntl.h> //file operations
#include <sys/mman.h> //Shared memory
#include <arpa/inet.h> //Address structure for sockets
#include <sys/socket.h> //Sockets
#include <zlib.h> //Compression
#include "shared.h"

//TODO: Move some of these constants to a config file
#define SERVER "192.168.21.1"
#define CLIENT "192.168.20.255"
#define BUFLEN 65507  //Max length of buffer
#define PORT 25000   //The port on which to send data

int main(int argc, char *argv[]) {
	//At first, open the shared memory. Other programs rely on this being present.
	struct SharedMemory* sharedMemory;
	int mfd, pipe = 0;
	openShm(&mfd, &sharedMemory, PROT_WRITE | PROT_READ, O_RDWR | O_CREAT);
	if (sharedMemory == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	//Forwarder is the only program that will create the shared memory.
	sharedMemory->softwareState = SW_FORWARDER;
	//Variable definitions
	//Address structs for the listening socktet and one for the designated receiver
	struct sockaddr_in si_me, si_other, si_out;
	int socket_in, socket_out, recv_len, reference_len = 0, broadcastEnable = 1;
	unsigned int slen = sizeof(si_other);
	unsigned char buf[BUFLEN], reference[BUFLEN], compressed[BUFLEN], type;
	long last;

	//Setup for listening socket
	if ((socket_in = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("Socket initialization failed.\n");
	}

	// zero out the structure
	memset((char *) &si_me, 0, sizeof(si_me));

	si_me.sin_family = AF_INET;
	si_me.sin_port = htons(PORT);
	if (inet_aton(SERVER, &si_me.sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}
	//bind socket to port
	while (bind(socket_in, (struct sockaddr*) &si_me, sizeof(si_me)) == -1) {
		printf("Network not ready (yet). Retrying in 10 seconds\n");
		sleep(10);
	}

	//Setup socket for sending data
	if ((socket_out = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("socket (out)");
	}


	memset((char *) &si_out, 0, sizeof(si_out));
	si_out.sin_family = AF_INET;
	si_out.sin_port = htons(PORT);

	if (inet_aton(CLIENT, &si_out.sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}

	setsockopt(socket_out, SOL_SOCKET, SO_BROADCAST, &broadcastEnable,
			sizeof(broadcastEnable));
	last = get_micros();

	//Receive loop
	while (1) {

		//try to receive some data, this is a blocking call
		if ((recv_len = recvfrom(socket_in, buf, BUFLEN, 0,
				(struct sockaddr *) &si_other, &slen)) == -1) {
			die("Receiving data failed.\n");
		}

		//Get the simulation time from the buffer before modifications
		long double simTime;
		memcpy(&simTime, buf + 1, 8);
		//Append statistics and status to buffer
		struct PacketFooter footer;
		footer.recorderStartTime = sharedMemory->recorderStartTime;
		footer.recorderState = sharedMemory->recordingState;
		footer.softwareState = sharedMemory->softwareState;
		footer.strSize = sizeof(footer);
		memcpy(buf + recv_len, &footer, footer.strSize);
		if (recv_len != reference_len) {
			//New reference packet
			printf("New reference %d != %d\n", recv_len, reference_len);
			memcpy(reference, buf, recv_len);
			//Remove the temporary file containing the previous reference packet
			char filename[sizeof(char) * strlen(TMP_DIR) + 5];
			sprintf(filename, "%s%x", TMP_DIR, reference_len);
			if (access(filename, F_OK)) {
				remove(filename);
			}
			reference_len = recv_len;
			type = 1;
		} else {
			//Delta packet
			//Xor the packet with the reference packet to improve the compression ratio
			for (int i = 0; i < recv_len; ++i) {
				buf[i] = reference[i] ^ buf[i];
			}
			type = 2;
		}
		//Compress the buffer to improve the performance of the wireless network
		z_stream strm;
		strm.zalloc = Z_NULL;
		strm.zfree = Z_NULL;
		strm.opaque = Z_NULL;
		if (deflateInit(&strm, 1) != Z_OK) {
			die("deflateInit failed\n");
		}
		strm.avail_in = recv_len + footer.strSize;
		strm.next_in = buf;
		strm.avail_out = BUFLEN;
		strm.next_out = compressed;
		if (deflate(&strm, Z_FINISH) != Z_STREAM_END) {
			die("Compression failed!\n");
		}
		int lenOut = strm.total_out;
		deflateEnd(&strm);
		//Add a footer to the data to be sent, in this way the receiver can find out what to do
		unsigned short chk = recv_len;
		memcpy(compressed + lenOut, &chk, 2);
		compressed[lenOut + 2] = type;
		//send the message
		if (sendto(socket_out, compressed, lenOut + 3, 0,
				(struct sockaddr *) &si_out, slen) == -1) {
			//Buffer for sending packets is full
			//The protocol does not fail on packet loss, so safely ignore this for now
			//TODO: implement packet loss statistics for local user interface
		}
		//If a new reference packet is generated, store this for the reference server program
		if (type == 1) {
			char filename[sizeof(char) * strlen(TMP_DIR) + 5];
			sprintf(filename, "%s%x", TMP_DIR, reference_len);
			unlink(filename);//Delete file first if it is already present somehow
			int fd = open(filename, O_WRONLY | O_CREAT);
			write(fd, compressed, lenOut + 3);
			close(fd);
		}
		if(sharedMemory->recordingState == (RECORDING_WANTED | RECORDING_STOPPED)){
			//Open recording pipe
			printf("Preparing for recording\n");
			char filename[sizeof(char) * strlen(TMP_DIR) + 9];
			sprintf(filename, "%s%x", TMP_DIR, sharedMemory->recorderStartTime);
			printf("Opening pipe for writing...\n");
			pipe = open(filename, O_WRONLY);
			//Write the reference packet to the pipe
			printf("Pipe opened. Writing metadata.\n");
			write(pipe, &reference_len, sizeof(reference_len));
			printf("Metdata written. Writing reference\n");
			write(pipe, reference, reference_len);
			printf("Reference written. Updating shared state to ready\n");
			//Set state to waiting for recorder program
			sharedMemory->recordingState = RECORDING_WANTED | RECORDING_RUNNING;
		}
		if((sharedMemory->recordingState & RECORDING_RUNNING) == RECORDING_RUNNING){
			if(sharedMemory->recordingState == RECORDING_RUNNING){//Without RECORDING_WANTED
				sharedMemory->recordingState = RECORDING_STOPPED;
			}
			int bSize = lenOut + 3;
			write(pipe, &bSize, sizeof(bSize));
			write(pipe, compressed, bSize);
		}
		if(sharedMemory->recordingState == RECORDING_STOPPED){
			char* nonsense = "\0";
			write(pipe, nonsense, 1);
		}
		if(sharedMemory->recordingState == 0 && pipe != 0){
			close(pipe);
			pipe = 0;
		}

		//Update statistics for the local user interface
		long now = get_micros();
		long double deltaSecs = (now - last) / 1000000.0;
		sharedMemory->packets = 1.0 / deltaSecs;
		last = now;
		sharedMemory->referenceLength = chk;
		sharedMemory->connected = 1;
		sharedMemory->simulationTime = simTime;
	}
	close(mfd);
	shutdown(socket_out, SHUT_RDWR);
	shutdown(socket_in, SHUT_RDWR);
}
