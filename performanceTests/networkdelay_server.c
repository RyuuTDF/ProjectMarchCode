/*
 Simple udp server
 Silver Moon (m00n.silv3r@gmail.com)
 */
#include <stdio.h> //printf
#include <string.h> //memset
#include <stdlib.h> //exit(0);
#include <arpa/inet.h>
#include <sys/socket.h>
#include <time.h>

#define BUFLEN 65507  //Max length of buffer
#define PORT 25000   //The port on which to listen for incoming data

void die(char *s) {
	perror(s);
	exit(1);
}

static long get_micros() {
	struct timespec ts;
	timespec_get(&ts, TIME_UTC);
	return (long) ts.tv_sec * 1000000L + ts.tv_nsec / 1000L;
}

int main(int argc, char *argv[]) {
	if (argc != 3) {
		die("Two arguments (packet count and output file name) expected!\n");
	}

	struct sockaddr_in si_me, si_other;

	int s, slen = sizeof(si_other), recv_len, recv_count = 0, exp_count = atoi(
			argv[1]);
	char buf[BUFLEN];

	//create a UDP socket
	if ((s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("Socket initialization failed.\n");
	}

	// zero out the structure
	memset((char *) &si_me, 0, sizeof(si_me));

	si_me.sin_family = AF_INET;
	si_me.sin_port = htons(PORT);
	si_me.sin_addr.s_addr = htonl(INADDR_ANY);

	//bind socket to port
	if (bind(s, (struct sockaddr*) &si_me, sizeof(si_me)) == -1) {
		die("Socket binding failed.\n");
	}
	FILE *outfile;
	outfile = fopen(argv[2], "w");
	fprintf(outfile, "%s\t%s\t%s\t%s\t%s", "rPacketNo", "rPacketTime",
			"rPacketTimeDouble");
	printf("Waiting for data to arrive\n");
	//keep listening for data
	while (recv_count < exp_count) {

		//try to receive some data, this is a blocking call
		if ((recv_len = recvfrom(s, buf, BUFLEN, 0,
				(struct sockaddr *) &si_other, &slen)) == -1) {
			die("Receiving data failed.\n");
		}
		long curTime = get_micros();
		if (recv_count == 0) {
			//Only notify once.
			printf("Receiving data\n");
		}
		double timeDouble = buf[1];
		int i = buf[9];

		fprintf(outfile, "%d\t%ld\t%lf", i, curTime, timeDouble);

		//TODO: log data time

		++recv_count;

	}
	fclose(outfile);
	close(s);
	return 0;
}
