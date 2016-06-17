/*
 * convert.c
 *
 *  Created on: 14 Jun 2016
 *      Author: ruben
 */

#include <stdio.h> //printf
#include <string.h> //memset
#include <stdlib.h> //exit(0);
#include <fcntl.h> //file operations
#include <zlib.h>
#include "shared.h"

#define BUFLEN 65507  //Max length of buffer

void help();

int main(int argc, char *argv[]){
	char inputFilename[255], outputFilename[255];
	int verbose = 0, testmode = 0, console = 1;
	int inFile, outFile;
	int pSize, written;
	char bufferIn[BUFLEN], bufferOut[BUFLEN], reference[BUFLEN];
	unsigned char decompressed[BUFLEN];
	short chk;
	memset(inputFilename, 0, 255);
	memset(outputFilename, 0, 255);
	if(argc < 2){
		printf("No arguments supplied. Start with -h for help.\n");
		return 1;
	}
	if(strcmp(argv[1], "-h") == 0){
		help();
		return 0;
	}else{
		memcpy(inputFilename, argv[1], strlen(argv[1]));
	}
	for(int i = 2; i < argc; ++i){
		if(strcmp(argv[i], "-t") == 0){
			testmode = 1;
		}else if(strcmp(argv[i], "-v") == 0){
			verbose = 1;
		}else{
			memcpy(outputFilename, argv[i], strlen(argv[i]));
			console = 0;
		}
	}
	if(console && verbose){
		printf("Verbose mode without output file is not supported\n");
		return 1;
	}
	if((inFile = open(inputFilename, O_RDONLY)) < 0){
		printf("Could not open input file %s for reading\n", inputFilename);
		perror(NULL);
		return 1;
	}
	if(!console && (outFile = open(outputFilename, O_WRONLY | O_CREAT)) < 0){
		printf("Could not open output file %s for writing\n", outputFilename);
		perror(NULL);
		return 1;
	}
	if(verbose) printf("Files opened. Reading reference packet...\n");
	int nr;
	if((nr = read(inFile, &pSize, sizeof(pSize))) != sizeof(pSize)){
		printf("Unreadable or empty file (ref: %i, sz: %i, r: %i)\n", pSize , sizeof(pSize), nr);
		return 1;
	}
	if(read(inFile, reference, pSize) != pSize){
		printf("Unexpected file size\n");
		return 1;
	}
	short reference_chk = pSize;
	if(testmode){
		written = sprintf(bufferOut, "time\ti\n");
	}else{
		written = sprintf(bufferOut, "time");
		int sensorCount = (pSize / 9 - 1) / 2;
		if((sensorCount * 2 + 1) * 9 != pSize){
			printf("Unexpected format of reference packet\n");
			return 1;
		}
		if(verbose)
			printf("Detected sensor count: %d\n", sensorCount);
		for(int i = 0; i < sensorCount; ++i){
			long double sensorId;
			memcpy(&sensorId, reference + 10 + i * 18, sizeof(sensorId));
			written += sprintf(bufferOut + written, "\tsensor_%.0Lf", sensorId);
		}
		written += sprintf(bufferOut + written, "\n");
	}
	if(console)
		printf(bufferOut);
	else
		write(outFile, bufferOut, written);
	if(verbose) printf("Header written\n");
	while(read(inFile, &pSize, sizeof(pSize)) == sizeof(pSize)){
		//Special case: end of file might contain zeroes
		if(pSize == 0)
			break;
		if(read(inFile, bufferIn, pSize) != pSize){
			printf("Data length does not match given length\n");
			return 1;
		}
		if(verbose)
			printf("Record of length %i read. Decompressing...\n", pSize);
		unsigned char compressed[pSize-3];
		memcpy(compressed, bufferIn, pSize-3);
		memcpy(&chk, bufferIn + pSize - 3, sizeof(chk));
		//Initialize ZLIB
		z_stream strm;
		/* allocate inflate state */
		strm.zalloc = Z_NULL;
		strm.zfree = Z_NULL;
		strm.opaque = Z_NULL;
		strm.avail_in = 0;
		strm.next_in = Z_NULL;
		int ret = inflateInit(&strm);
		if (ret != Z_OK){
			perror("Not ok...\n");
			return ret;
		}
		strm.avail_in = pSize - 3;
		strm.next_in = compressed;
		strm.avail_out = BUFLEN;
		strm.next_out = decompressed;
		ret = inflate(&strm, Z_NO_FLUSH);
		if(ret != Z_STREAM_END){
			printf("End of stream not reached!\n");
			return ret;
		}
		inflateEnd(&strm);
		if(reference_chk != chk){
			if(verbose)
				printf("New reference packet (should be rare): %i != %i\n", reference_chk, chk);
			memcpy(reference, decompressed, chk);
			reference_chk = chk;
		}else{
			for(int i = 0; i < chk; i ++){
				decompressed[i] = decompressed[i] ^ reference[i];
			}
		}
		long double time;
		memcpy(&time, decompressed+1, sizeof(time));
		if(verbose)
			printf("Evaluating data for packet with sim time %Lf\n", time);
		memset(bufferOut, 0, BUFLEN);
		written = sprintf(bufferOut, "%Lf", time);
		if(testmode){
			int i;
			memcpy(&i, decompressed + 9, sizeof(i));
			written += sprintf(bufferOut + written, "%d", i);
		}else{
			//Iterate over all sensors
			int sensorCount = (chk - 9) / 18;
			if(sensorCount * 18 + 9 != chk){
				printf("Unexpected format of data packet\n");
				return 1;
			}
			if(verbose)
				printf("Packet has %d sensors\n", sensorCount);

			for(int i = 0; i < sensorCount; ++i){
				long double sensorData;
				memcpy(&sensorData, decompressed + 19 + i * 18, sizeof(sensorData));
				written += sprintf(bufferOut + written, "\t%Lf", sensorData);
			}
			written += sprintf(bufferOut + written, "\n");
		}
		if(console)
			printf(bufferOut);
		else
			write(outFile, bufferOut, written);
		if(verbose) printf("Packet written\n");
	}
	if(verbose)
		printf("End of input file reached. Conversion finished\n");
	if(!console){
		close(outFile);
	}
	close(inFile);

	return 0;
}

void help(){
	printf("convert - covert a recording made by recorder to a text file\n");
	printf("Usage:\n");
	printf("\tconvert [-h] inputfile [outputfile] [-t] [-v]\n");
	printf("\n");
	printf("-h\n");
	printf("\tDisplay this message and quit\n");
	printf("inputfile\n");
	printf("\tA file containing a recording\n");
	printf("outputfile\n");
	printf("\tThe file to write the output to. Required with -v option. Without a specified filename, the output will be written to standard out.\n");
	printf("-t\n");
	printf("\tTest mode. Use this flag when the recording is made when running the network test tools.\n");
	printf("-v\n");
	printf("\tPrint (somewhat?) useful information to the standard out when processing the file. An output file has to be specified for this option to work.\n");
	printf("-------------\n");
	printf("This program is part of a set of tools written for the monitoring system for the exoskeleton of Project MARCH\n");
	printf("Written by Ruben Visser (r.visser at lunoct dot nl). Part of the bachelor thesis project of Jens Voortman, Vasco de Bruin and Ruben Visser.\n");
}
