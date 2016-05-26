/*
 * forwarder.c
 *
 *  Created on: 25 May 2016
 *      Author: ruben
 */


#include <stdio.h> //printf
#include <string.h> //memset
#include <stdlib.h> //exit(0);
#include <arpa/inet.h>
#include <sys/socket.h>
#include <zlib.h>

#define SERVER "192.168.21.1"
#define CLIENT "192.168.20.255"
#define BUFLEN 65507  //Max length of buffer
#define PORT 25000   //The port on which to send data

void die(char *s)
{
	perror(s);
	exit(1);
}

int main(int argc, char *argv[])
{
	struct sockaddr_in si_me, si_other, si_out;

	int s_in, s_out, recv_len;
	unsigned int slen = sizeof(si_other);

	unsigned char buf[BUFLEN], reference[BUFLEN], compressed[BUFLEN], type;

	int refLength = 0;

	//create a UDP socket
	if ((s_in=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1)
	{
		die("Socket initialization failed.\n");
	}

	// zero out the structure
	memset((char *) &si_me, 0, sizeof(si_me));

	si_me.sin_family = AF_INET;
	si_me.sin_port = htons(PORT);
	if (inet_aton(SERVER , &si_me.sin_addr) == 0)
	{
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}
	//si_me.sin_addr.s_addr = htonl(INADDR_ANY);

	//bind socket to port
	if( bind(s_in , (struct sockaddr*)&si_me, sizeof(si_me) ) == -1)
	{
		die("Socket binding failed.\n");
	}

	if ( (s_out=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1)
	{
		die("socket (out)");
	}

	memset((char *) &si_out, 0, sizeof(si_out));
	si_out.sin_family = AF_INET;
	si_out.sin_port = htons(PORT);

	if (inet_aton(CLIENT , &si_out.sin_addr) == 0)
	{
		fprintf(stderr, "inet_aton() failed\n");
		exit(1);
	}

	int broadcastEnable=1;
	setsockopt(s_out, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, sizeof(broadcastEnable));

	//keep listening for data
	while(1)
	{


		//try to receive some data, this is a blocking call
		if ((recv_len = recvfrom(s_in, buf, BUFLEN, 0, (struct sockaddr *) &si_other, &slen)) == -1)
		{
			die("Receiving data failed.\n");
		}

		if(recv_len != refLength){
			//New reference packet
			printf("New reference %d != %d\n", recv_len, refLength);
			memcpy(reference, buf, recv_len);
			refLength = recv_len;
			type = 1;
		}else{
			//Delta packet
			for(int i = 0; i < recv_len; ++i){
				buf[i] = reference[i] ^ buf[i];
			}
			//memcpy(buf, xorred, recv_len);
			type = 2;
		}
		z_stream strm;
		strm.zalloc = Z_NULL;
		strm.zfree = Z_NULL;
		strm.opaque = Z_NULL;
		if(deflateInit(&strm, 1) != Z_OK){
			die("deflateInit failed\n");
		}
		strm.avail_in = recv_len;
		strm.next_in = buf;
		strm.avail_out = BUFLEN;
		strm.next_out = compressed;
		if(deflate(&strm, Z_FINISH) != Z_STREAM_END){
			die("Compression failed!\n");
		}
		int lenOut = strm.total_out;
		deflateEnd(&strm);
		short chk = recv_len;
		memcpy(compressed + lenOut, &chk, 2);
		compressed[lenOut + 2] = type;
		//send the message
		if (sendto(s_out, compressed, lenOut + 3, 0 , (struct sockaddr *) &si_out, slen)==-1)
		{
			//die("sendto()");
			//printf("Package lost...\n");
			//Package lost... Well, ignore for now...
		}
	}
	shutdown(s_out, SHUT_RDWR);
	shutdown(s_in, SHUT_RDWR);
}
