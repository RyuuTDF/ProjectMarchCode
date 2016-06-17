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
		(command, source, destination) = tuple(line[:-1].split("\t", 3))
		if command == 'modify':
			modify(source, destination)
		elif command == 'append':
			append(source, destination)
		else:
			replace(source, destination)
	config.close()

# # def modify
# Modifies a file according to given directions
# @param source The file containing the modification directions
# @param destination The file to apply the modifications to
def modify(source, destination):
	if os.path.exists(destination):
		shutil.move(destination, destination + ".bak")
		print "Applying modifications to " + source
		replaceList = readReplacements(source)
		with open(destination, 'w') as output:
			with open(destination + ".bak") as input:
				for inputLine in input:
					outputLine = replaceWithList(inputLine, replaceList[:])
					output.write(outputLine.replace("\\n", "\n"))
	else:
		print "ERROR: can't modify non-existing file " + source + "!"

# # def append
# Appends the contents of a file to another one
# @param source The file with the contents to be apppended
# @param destination The file which has to be appended to
def append(source, destination):
	if not checkPathFor(destination):
		return
	if os.path.exists(destination):
		shutil.copy(destination, destination + ".bak")
	else:
		print "Warning: appending to non-existing file " + source + " (new file will be created)"
	print "Adding configuration options to " + source
	with open(destination, 'a') as output:
		with open(source) as input:
			for inputLine in input:
				output.write(inputLine)

# # def replace
# Replace a file by another file (or create a new file)
# @param source The file with the new contents
# @param destination The file to be replaced or created
def replace(source, destination):
	if not checkPathFor(destination):
		return
	if os.path.exists(destination):
		shutil.move(destination, destination + ".bak")
	print "Replacing file " + source
	shutil.copy(source, destination)

# # def replaceWithList
# Replaces all occurences of replace directions in a list in a string
# @param subject String containing text to be replaced
# @param replaceList List of replacement directions
def replaceWithList(subject, replaceList):
	if len(replaceList) == 0:
		return subject
	else:
		last = replaceList.pop()
		return replaceWithList(subject.replace(last[0], last[1]), replaceList)

# # def readReplacements
# Reads replacement directions from a file into a list
# @param input Filename of the file containing the directions
# @return List of replacement directions
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


# # def checkPathFor
# Will check if path exists for filename, and if not try to create required directories
# @param filename Name of the file that will be created after 
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
