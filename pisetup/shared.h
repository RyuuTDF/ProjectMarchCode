/*
 * shared.h
 *
 *  Created on: 7 Jun 2016
 *      Author: ruben
 */

#ifndef SHARED_H_
#define SHARED_H_

#include <sys/mman.h> //Shared memory
#include <sys/types.h>
#include <stdlib.h>
#include <unistd.h>

#define MMAPFILE "/run/exoshm"
#define TMP_DIR "/run/"

#define RECORDING_WANTED 0x00000001
#define RECORDING_STOPPED 0x00000002
#define RECORDING_RUNNING 0x00000004
#define RECORDING_FAILED 0x00000008

#define SW_FORWARDER 0x00000001
#define SW_REFERENCE 0x00000002
#define SW_RECORDER 0x00000004
#define SW_HTTP 0x00000008

//Define as packed to prevent alignment surprises
typedef struct __attribute__((__packed__)) SharedMemory {
	long connected; //4B [0-3]
	long double packets; //8B [4-11]
	long double simulationTime; //8B [12-19]
	short referenceLength; //2B [20-21]
	short recordingState; //2B [22-23]
	short softwareState; //2B [24-25]
	long int recorderStartTime; //4B [26-29]
} SharedMemory;

int openShm(int* fd, struct SharedMemory** sharedMemPointer, int mapProt,
		int fileFlags) {
	//Open the memory map with requested flags
	*fd = open(MMAPFILE, fileFlags);
	if (*fd == -1) {
		perror("open");
		return 1;
	}
	if ((fileFlags & O_CREAT) == O_CREAT) {
		//Request to open a new file. Fill this new file with zeroes
		char mt[getpagesize()];
		//Write data with the size of one page to initialise the file and memory
		write(*fd, mt, getpagesize());
	}
	*sharedMemPointer = mmap((caddr_t) 0, getpagesize(), mapProt, MAP_SHARED,
			*fd, 0);
	if (*sharedMemPointer == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	return 0;
}

typedef struct __attribute__((__packed__)) PacketFooter {
	unsigned long recorderStartTime; //4B
	int recorderState; //4B
	int softwareState; //4B
	unsigned char strSize; //1B
} PacketFooter;

/**
 * Helper function for printing errors and aborting the program.
 */
void die(char *s) {
	perror(s);
	exit(1);
}

#endif /* SHARED_H_ */
