/*
 * recorder.c
 * 
 * Writes the data for a recording to the designated file
 *
 *  Created on: 9 Jun 2016
 *      Author: ruben
 */


#include <stdio.h> //printf
#include <stdlib.h> //exit(0);
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>//mkfifo
#include <time.h>
#include "shared.h"

#define BUFLEN 65507  //Max length of buffer
#define RECORDING_DIR "/home/pi/recordings/"

int main(int argc, char *argv[]) {
	//Variable definitions
	char fileNamePart[32], filename[64];
	int recv_len, outputFile, pipe, mmapFile;
	unsigned char buffer[BUFLEN];
	struct tm time;
	struct SharedMemory* sharedMemory;
	//At first, open the shared memory. Details on the recording request can be found there
	openShm(&mmapFile, &sharedMemory, PROT_WRITE | PROT_READ, O_RDWR);
	if (sharedMemory == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	if((sharedMemory->recordingState & RECORDING_WANTED) != RECORDING_WANTED){
		printf("Recorder started without request. Confused....\n");
		return 1;
	}
	sharedMemory->softwareState = sharedMemory->softwareState | SW_RECORDER;
	
	//Open the output file
	localtime_r(&sharedMemory->recorderStartTime, &time);
	strftime(fileNamePart, 32, "%Y%m%d%H%M%S.rec", &time);
	sprintf(filename, "%s%s", RECORDING_DIR, fileNamePart);
	outputFile = open(filename, O_RDWR | O_CREAT);

	//Open the named pipe
	char pipename[sizeof(char) * strlen(TMP_DIR) + 5];
	sprintf(pipename, "%s%lx", TMP_DIR, sharedMemory->recorderStartTime);
	mkfifo(pipename, 0600);
	sharedMemory->recordingState = (sharedMemory->recordingState | RECORDING_STOPPED);

	pipe = open(pipename, O_RDONLY);//BLOCKING call!
	//Receive loop
	while ((sharedMemory->recordingState != RECORDING_STOPPED) && (sharedMemory->recordingState!=0)) {
		//try to receive some data, this is a blocking call
		if ((recv_len = read(pipe, buffer, BUFLEN)) == -1) {
			die("Receiving data failed.\n");
		}
		write(outputFile, buffer, recv_len);
	}
	if(sharedMemory->recordingState==0){
		printf("Recording stopped, state was unexpected!\n");
	}
	close(outputFile);
	close(pipe);
	sharedMemory->recordingState = 0;
	if((sharedMemory->softwareState & SW_RECORDER) == SW_RECORDER)
		sharedMemory->softwareState -= SW_RECORDER;
	close(mmapFile);
	return 0;
}
