#!/usr/bin/python
# -------------------------------------------------------------
# Auto installation tool for Raspberry Pi to be used on the
# Project MARCH exoskeleton as connection bridge to an external
# monitoring client. This script should be called by startsetup

import os.path
import os
import shutil
import sys


def run():
	config = open('filelist', 'r')
	for line in config:
		if line[0] == '#':
			continue
		(command, source, destination) =  tuple(line[:-1].split("\t", 3))
		if command == 'modify':
			if os.path.exists(destination):
				shutil.move(destination, destination + ".bak")
				print "Applying modifications to " + source
				replaceList = readReplacements(source)
				with open(destination, 'w') as output:
					with open(destination + ".bak") as input:
						for inputLine in input:
							output.write(replaceWithList(inputLine, replaceList[:]))
			else:
				print "ERROR: can't modify non-existing file " + source + "!"
				
		elif command == 'append':
			if not checkPathFor(destination):
				continue
			if os.path.exists(destination):
				shutil.copy(destination, destination + ".bak")
			else:
				print "Warning: appending to non-existing file " + source + " (new file will be created)"
			print "Adding configuration options to " + source
			with open(destination, 'a') as output:
				with open(source) as input:
					for inputLine in input:
						output.write(inputLine)
		else:
			if not checkPathFor(destination):
				continue
			if os.path.exists(destination):
				shutil.move(destination, destination + ".bak")
			print "Replacing file " + source
			shutil.copy(source, destination)
	config.close()


def replaceWithList(target, replaceList):
	if len(replaceList) == 0:
		return target
	else:
		last = replaceList.pop()
		return replaceWithList(target.replace(last[0], last[1]), replaceList)


def readReplacements(input):
	resultList = []
	with open(input) as file:
		skip = 2
		line = file.readline()
		while line != '':
			if skip > 0:
				skip = skip - 1
			else:
				resultList.append((line[:-1], file.readline()[:-1]))
			line = file.readline()
	return resultList


## def checkPathFor
# Will check if path exists for filename, and if not try to create required directories
# @param filename
def checkPathFor(filename):
	directory = os.path.dirname(filename)
	if not os.path.exists(directory):
		os.makedirs(directory)
	return True;


if __name__ == "__main__":
	oldDir = os.getcwd()
	os.chdir(sys.path[0])
	run()
	os.chdir(oldDir)
