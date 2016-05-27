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
#include <time.h> // Performance timing
#include <sys/mman.h> //Shared memory
#include <arpa/inet.h> //Address structure for sockets
#include <sys/socket.h> //Sockets
#include <zlib.h> //Compression

//TODO: Move some of these constants to a config file
#define SERVER "192.168.21.1"
#define CLIENT "192.168.20.255"
#define MMAPFILE "/run/exoshm"
#define TMP_DIR "/run/"
#define BUFLEN 65507  //Max length of buffer
#define PORT 25000   //The port on which to send data

/**
 * Returns the current time in microsecond resolution. Suitable for performance timing.
 */
static long get_micros() {
	struct timespec ts;
	timespec_get(&ts, TIME_UTC);
	return (long) ts.tv_sec * 1000000L + ts.tv_nsec / 1000L;
}

/**
 * Helper function for printing errors and aborting the program.
 */
void die(char *s) {
	perror(s);
	exit(1);
}

/**
 * Update the shared memory with the given values.
 */
int updateShm(char* mem, int connected, long double packets,
		long double simTime, short chk) {
	memcpy(mem, &connected, 4);
	memcpy(mem + 4, &packets, 8);
	memcpy(mem + 12, &simTime, 8);
	memcpy(mem + 20, &chk, 2);
	return 0;
}

int main(int argc, char *argv[]) {
	//At first, open the shared memory. Other programs rely on this being present.
	int mfd = open(MMAPFILE, O_RDWR | O_CREAT);
	if (mfd == -1) {
		perror("open");
		return 1;
	}
	char mt[getpagesize()];
	//Write data with the size of one page to initialise the file and memory
	write(mfd, mt, getpagesize());
	char* shMem = mmap((caddr_t) 0, getpagesize(), PROT_WRITE | PROT_READ,
			MAP_SHARED, mfd, 0);
	if (shMem == MAP_FAILED) {
		perror("mmap");
		return 1;
	}

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
		strm.avail_in = recv_len;
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
			//Buffer for sending packats is full
			//The protocol does not fail on packet loss, so safely ignore this for now
			//TODO: implement packet loss statistics for local user interface
		}
		//If a new reference packet is generated, store this for the reference server program
		if (type == 1) {
			char filename[sizeof(char) * strlen(TMP_DIR) + 5];
			sprintf(filename, "%s%x", TMP_DIR, reference_len);
			int fd = open(filename, O_WRONLY | O_CREAT);
			write(fd, compressed, lenOut + 3);
			close(fd);
		}
		//Update statistics for the local user interface
		long now = get_micros();
		long double packets = 1000000.0 / (now - last);
		last = now;
		updateShm(shMem, 1, packets, simTime, chk);
	}
	close(mfd);
	shutdown(socket_out, SHUT_RDWR);
	shutdown(socket_in, SHUT_RDWR);
}
