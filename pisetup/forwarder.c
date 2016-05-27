/*
 * forwarder.c
 *
 *  Created on: 25 May 2016
 *      Author: ruben
 */

#include <stdio.h> //printf
#include <string.h> //memset
#include <stdlib.h> //exit(0);
#include <fcntl.h>
#include <time.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <zlib.h>

#define SERVER "192.168.21.1"
#define CLIENT "192.168.20.255"
#define MMAPFILE "/run/exoshm"
#define TMP_DIR "/run/"
#define BUFLEN 65507  //Max length of buffer
#define PORT 25000   //The port on which to send data

static long get_micros() {
	struct timespec ts;
	timespec_get(&ts, TIME_UTC);
	return (long) ts.tv_sec * 1000000L + ts.tv_nsec / 1000L;
}

void die(char *s) {
	perror(s);
	exit(1);
}

int openShm(char** mem) {
	int fd = open(MMAPFILE, O_RDWR);
	*mem = mmap((caddr_t) 0, getpagesize(), PROT_WRITE | PROT_READ, MAP_SHARED,
			fd, 0);
	return 0;
}

int updateShm(char* mem, int connected, long double packets,
		long double simTime, short chk) {
	memcpy(mem, &connected, 4);
	memcpy(mem + 4, &packets, 8);
	memcpy(mem + 12, &simTime, 8);
	memcpy(mem + 20, &chk, 2);
	return 0;
}

int main(int argc, char *argv[]) {
	struct sockaddr_in si_me, si_other, si_out;

	int s_in, s_out, recv_len;
	unsigned int slen = sizeof(si_other);

	unsigned char buf[BUFLEN], reference[BUFLEN], compressed[BUFLEN], type;

	int refLength = 0;

	//create a UDP socket
	if ((s_in = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
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
	if (bind(s_in, (struct sockaddr*) &si_me, sizeof(si_me)) == -1) {
		die("Socket binding failed.\n");
	}

	if ((s_out = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("socket (out)");
	}

	memset((char *) &si_out, 0, sizeof(si_out));
	si_out.sin_family = AF_INET;
	si_out.sin_port = htons(PORT);

	if (inet_aton(CLIENT, &si_out.sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}

	int broadcastEnable = 1;
	setsockopt(s_out, SOL_SOCKET, SO_BROADCAST, &broadcastEnable,
			sizeof(broadcastEnable));
	long last = get_micros();
	/*char* shMem;
	 openShm(&shMem);*/
	int mfd = open(MMAPFILE, O_RDWR | O_CREAT);
	if (mfd == -1) {
		perror("open");
		return 1;
	}
	char mt[getpagesize()];
	write(mfd, mt, getpagesize());
	char* shMem = mmap((caddr_t) 0, getpagesize(), PROT_WRITE | PROT_READ,
			MAP_SHARED, mfd, 0);
	if (shMem == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	//keep listening for data
	while (1) {

		//try to receive some data, this is a blocking call
		if ((recv_len = recvfrom(s_in, buf, BUFLEN, 0,
				(struct sockaddr *) &si_other, &slen)) == -1) {
			die("Receiving data failed.\n");
		}

		long double simTime;
		memcpy(&simTime, buf + 1, 8);

		if (recv_len != refLength) {
			//New reference packet
			printf("New reference %d != %d\n", recv_len, refLength);
			memcpy(reference, buf, recv_len);
			char filename[sizeof(char) * strlen(TMP_DIR) + 5];
			sprintf(filename, "%s%x", TMP_DIR, refLength);
			if (access(filename, F_OK)) {
				remove(filename);
			}
			refLength = recv_len;
			type = 1;
		} else {
			//Delta packet
			for (int i = 0; i < recv_len; ++i) {
				buf[i] = reference[i] ^ buf[i];
			}
			//memcpy(buf, xorred, recv_len);
			type = 2;
		}
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
		unsigned short chk = recv_len;
		memcpy(compressed + lenOut, &chk, 2);
		compressed[lenOut + 2] = type;
		//send the message
		if (sendto(s_out, compressed, lenOut + 3, 0,
				(struct sockaddr *) &si_out, slen) == -1) {
			//die("sendto()");
			//printf("Package lost...\n");
			//Package lost... Well, ignore for now...
		}
		if (type == 1) {
			//Store in file
			char filename[sizeof(char) * strlen(TMP_DIR) + 5];
			sprintf(filename, "%s%x", TMP_DIR, refLength);
			int fd = open(filename, O_WRONLY | O_CREAT);
			write(fd, compressed, lenOut + 3);
			close(fd);
		}
		long now = get_micros();
		long double packets = 1000000.0 / (now - last);
		last = now;
		updateShm(shMem, 1, packets, simTime, chk);
	}
	close(mfd);
	shutdown(s_out, SHUT_RDWR);
	shutdown(s_in, SHUT_RDWR);
}
