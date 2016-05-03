#!/usr/bin/python
# -------------------------------------------------------------
# Auto installation tool for Raspberry Pi to be used on the
# Project MARCH exoskeleton as connection bridge to an external
# monitoring client. This script should be called by startsetup

import os.path
import os
import shutil


def run():
    config = open('filelist', 'r')
    for line in config:
        if line[0] == '#':
            continue
        (command, source, destination) =  tuple(line[:-1].split("\t", 3))
        print "Command " + command + " for file " + source + " found: destination " + destination
	if command == 'modify':
		(something)
		if path.exists(destination):
			shutil.copy(destination, destination + ".bak")
			
	elif command == 'append':
		(something)
		if path.exists(destination):
			shutil.copy(destination, destination + ".bak")
	else:
		(replace)
		checkPathFor(destination)
		if path.exists(destination):
			shutil.move(destination, destination + ".bak")
		shutil.copy(source, destination)
		

## def checkPathFor
# Will check if path exists for filename, and if not try to create required directories
# @param filename
def checkPathFor(filename):
	directory = realpath(filename)
	if ! isdir(directory):
		

if __name__ == "__main__":
    run()
