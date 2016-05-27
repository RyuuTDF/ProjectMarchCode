/*
 Simple udp client
 Silver Moon (m00n.silv3r@gmail.com)
 */
#include<stdio.h> //printf
#include<string.h> //memset
#include<stdlib.h> //exit(0);
#include<arpa/inet.h>
#include<sys/socket.h>
#include <time.h>

#define SERVER "192.168.21.1"
#define BUFLEN 65507  //Max length of buffer
#define PORT 25000   //The port on which to send data

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
	if (argc != 5) {
		die("Four arguments expected! (count, size, rate, output file)\n");
	}
	int count = atoi(argv[1]), size = atoi(argv[2]), rate = atoi(argv[3]);
	if (size < 13) {
		die("Package size should be at least 13 bytes\n");
	}
	if (size > BUFLEN) {
		die("Package size should not exceed maximum package size\n");
	}
	struct sockaddr_in si_other;
	int s, i, slen = sizeof(si_other);
	char message[BUFLEN];
	double timeDouble;
	long interval = 1000000L / rate;

	if ((s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1) {
		die("socket");
	}

	memset((char *) &si_other, 0, sizeof(si_other));
	si_other.sin_family = AF_INET;
	si_other.sin_port = htons(PORT);

	if (inet_aton(SERVER, &si_other.sin_addr) == 0) {
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}
	FILE *outfile;
	outfile = fopen(argv[4], "w");
	fprintf(outfile, "%s\t%s\t%s\t%s\t%s", "sPacketNo", "sPacketTime",
			"sPacketTimeDouble", "packetRate", "packetSize");
	long startTime = get_micros();
	long next = startTime;
	for (i = 0; i < count; ++i) {
		next = next + interval;
		long curTime = get_micros();
		memset(message, 0, size);
		timeDouble = (startTime - curTime) / 1000000.0f;
		message[0] = 1;
		message[1] = timeDouble;
		message[9] = i;
		fprintf(outfile, "%d\t%ld\t%lf\t%d\t%d", i, curTime, timeDouble, rate,
				size);

		//send the message
		if (sendto(s, message, size, 0, (struct sockaddr *) &si_other, slen)
				== -1) {
			die("sendto()");
		}
		usleep(next - curTime);
	}
	fclose(outfile);
	close(s);
	return 0;
}
