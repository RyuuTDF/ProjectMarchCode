/*
 * reference.c
 *
 *  Created on: 26 May 2016
 *      Author: ruben
 */
#include <stdio.h> //printf
#include <string.h> //memset
#include <stdlib.h> //exit(0);
#include <fcntl.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define SERVER "192.168.20.1"
#define MMAPFILE "/run/exoshm"
#define TMP_DIR "/run/"
#define BUFLEN 65507  //Max length of buffer
#define PORT_IN 25001   //The port on which to send data
#define PORT_OUT 25000   //The port on which to send data

void die(char *s) {
	perror(s);
	exit(1);
}

int main(int argc, char *argv[]) {
	struct sockaddr_in si_me, si_other, si_out;

	int s_in, s_out, recv_len;
	unsigned int slen = sizeof(si_other);
	unsigned char buf[BUFLEN], compressed[BUFLEN];

	//create a UDP socket
	if ((s_in = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("Socket initialization failed.\n");
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
	if (bind(s_in, (struct sockaddr*) &si_me, sizeof(si_me)) == -1) {
		die("Socket binding failed.\n");
	}

	if ((s_out = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("socket (out)");
	}

	memset((char *) &si_out, 0, sizeof(si_out));
	si_out.sin_family = AF_INET;
	si_out.sin_port = htons(PORT_OUT);

	int mfd = open(MMAPFILE, O_RDONLY | O_CREAT);
	if (mfd == -1) {
		perror("open");
		return 1;
	}
	char* shMem = mmap((caddr_t) 0, getpagesize(), PROT_READ, MAP_SHARED, mfd,
			0);
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

		si_out.sin_addr = si_other.sin_addr;

		short chk;
		memcpy(&chk, buf, 2);
		char filename[sizeof(char) * strlen(TMP_DIR) + 5];
		sprintf(filename, "%s%x", TMP_DIR, chk);
		printf("Request from %x for file %s\n", si_out.sin_addr, filename);
		if (access(filename, R_OK) != -1) {
			int fd = open(filename, O_RDONLY);
			if (fd == -1) {
				printf("Accessing file failed!\n");
				continue;
			}
			int packedSize = read(fd, compressed, BUFLEN);
			close(fd);

			if (sendto(s_out, compressed, packedSize, 0,
					(struct sockaddr *) &si_out, slen) == -1) {
				printf("Package lost...\n");
				//Package lost... Well, ignore for now... Client will request a new one anyway
			}
		} else {
			printf("Request for unknown packet %x\n", chk);
		}
	}
	close(mfd);
	shutdown(s_out, SHUT_RDWR);
	shutdown(s_in, SHUT_RDWR);
}
