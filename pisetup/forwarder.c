/*
 * forwarder.c
 * 
 * UDP server that will forward packets received to any connected client on the wireless interface
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
#include "timing.h"
#include "udpserver.h"

//TODO: Move some of these constants to a config file
#define SERVER "192.168.21.1"
#define CLIENT "192.168.20.255"
#define BUFLEN 65507  //Max length of buffer
#define PORT 25000   //The port on which to send data

/**
 * compresses buffer in (size sz_in) to buffer out (max size sz_out). Returns compressed size
 */
int compressBuffer(unsigned char* out, const int sz_out, unsigned char* in,
		const int sz_in) {
	z_stream strm;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	if (deflateInit(&strm, 1) != Z_OK) {
		die("deflateInit failed\n");
	}
	strm.avail_in = sz_in;
	strm.next_in = in;
	strm.avail_out = sz_out;
	strm.next_out = out;
	if (deflate(&strm, Z_FINISH) != Z_STREAM_END) {
		die("Compression failed!\n");
	}
	int lenOut = strm.total_out;
	deflateEnd(&strm);
	return lenOut;
}

/**
 * Converts a received packet into the format to be sent to a client.
 */
int buildPacket(SharedMemory* sharedMemory, unsigned char* buffer_in,
		const int sz_in, unsigned char* buffer_out, unsigned char* reference) {
	char type;
	//Append statistics and status to buffer
	struct PacketFooter footer;
	footer.recorderStartTime = sharedMemory->recorderStartTime;
	footer.recorderState = sharedMemory->recordingState;
	footer.softwareState = sharedMemory->softwareState;
	footer.strSize = sizeof(footer);
	memcpy(buffer_in + sz_in, &footer, footer.strSize);
	if (sz_in != sharedMemory->referenceLength) {
		//New reference packet
		printf("New reference %d != %d\n", sz_in,
				sharedMemory->referenceLength);
		memcpy(reference, buffer_in, sz_in);
		//Remove the temporary file containing the previous reference packet
		char filename[sizeof(char) * strlen(TMP_DIR) + 5];
		sprintf(filename, "%s%x", TMP_DIR, sharedMemory->referenceLength);
		if (access(filename, F_OK)) {
			remove(filename);
		}
		sharedMemory->referenceLength = sz_in;
		type = 1;
	} else {
		//Delta packet
		//Xor the packet with the reference packet to improve the compression ratio
		for (int i = 0; i < sz_in; ++i) {
			buffer_in[i] = reference[i] ^ buffer_in[i];
		}
		type = 2;
	}
	//Compress the buffer to improve the performance of the wireless network
	int lenOut = compressBuffer(buffer_out, BUFLEN, buffer_in,
			sz_in + footer.strSize);
	//Add a footer to the data to be sent, in this way the receiver can find out what to do
	unsigned short chk = sz_in;
	memcpy(buffer_out + lenOut, &chk, 2);
	buffer_out[lenOut + 2] = type;
	lenOut += 3;		//Reflect the added bytes in the size
	//If a new reference packet is generated, store this for the reference server program
	if (type == 1) {
		char filename[sizeof(char) * strlen(TMP_DIR) + 5];
		sprintf(filename, "%s%x", TMP_DIR, sz_in);
		unlink(filename);	//Delete file first if it is already present somehow
		int fd = open(filename, O_WRONLY | O_CREAT);
		write(fd, buffer_out, lenOut);
		close(fd);
	}
	return lenOut;
}

/**
 * Open the recording pipe and start writing to it
 */
int startRecording(const long int time, const unsigned char* reference,
		const int reference_len) {
	//Open recording pipe
	char filename[sizeof(char) * strlen(TMP_DIR) + 9];
	sprintf(filename, "%s%lx", TMP_DIR, time);
	int pipe = open(filename, O_WRONLY);
	//Write the reference packet to the pipe
	write(pipe, &reference_len, sizeof(reference_len));
	write(pipe, reference, reference_len);
	return pipe;
}

/**
 * Check recording state and handle accordingly
 */
void handleRecording(short* state, const long int time, int* pipe,
		const unsigned char* buffer, const int buf_len,
		const unsigned char* reference, const int reference_len) {
	if (*state == (RECORDING_WANTED | RECORDING_STOPPED)) {
		*pipe = startRecording(time, reference, reference_len);
		//Set state to waiting for recorder program
		*state = RECORDING_WANTED | RECORDING_RUNNING;
	}
	if ((*state & RECORDING_RUNNING) == RECORDING_RUNNING) {
		if (*state == RECORDING_RUNNING) {	//Without RECORDING_WANTED
			*state = RECORDING_STOPPED;
		}
		int bSize = buf_len;
		write(*pipe, &bSize, sizeof(bSize));
		write(*pipe, buffer, bSize);
	}
	if (*state == RECORDING_STOPPED) {
		char* nonsense = "\0";
		write(*pipe, nonsense, 1);
	}
	if (*state == 0 && *pipe != 0) {
		close(*pipe);
		pipe = 0;
	}
}

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
	struct sockaddr_in si_other, si_out;
	int socket_in, socket_out, recv_len;
	unsigned int slen = sizeof(si_other);
	unsigned char buf[BUFLEN], reference[BUFLEN], compressed[BUFLEN];
	long last;

	socket_in = openUdpListener(SERVER, PORT);
	socket_out = openUdpSender(1);
	siFormat(&si_out, CLIENT, PORT);

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
		int lenOut = buildPacket(sharedMemory, buf, recv_len, compressed,
				reference);
		//send the message
		sendto(socket_out, compressed, lenOut, 0, (struct sockaddr *) &si_out,
				slen);
		handleRecording(&sharedMemory->recordingState,
				sharedMemory->recorderStartTime, &pipe, compressed, lenOut,
				reference, sharedMemory->referenceLength);
		//Update statistics for the local user interface
		long now = get_micros();
		long double deltaSecs = (now - last) / 1000000.0;
		sharedMemory->packets = 1.0 / deltaSecs;
		last = now;
		sharedMemory->connected = 1;
		sharedMemory->simulationTime = simTime;
	}
	close(mfd);
	shutdown(socket_out, SHUT_RDWR);
	shutdown(socket_in, SHUT_RDWR);
}
