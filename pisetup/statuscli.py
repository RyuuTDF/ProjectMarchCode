#!/usr/bin/python

import mmap
import os
import struct
import time

def main():
    # Open the file for reading
    fd = os.open('/run/exoshm', os.O_RDONLY)

    # Memory map the file
    buf = mmap.mmap(fd, mmap.PAGESIZE, mmap.MAP_SHARED, mmap.PROT_READ)

    connected = None
    packetRate = None

    while 1:
        new_c, = struct.unpack('i', buf[:4])
        new_p, = struct.unpack('f', buf[4:8])

        if connected != new_c or packetRate != new_p:
            print 'Connected: %d' % (new_c)
            print 'Packets per sec: %d' % (new_p)
            connected = new_c
            packetRate = new_p

        time.sleep(1)


if __name__ == '__main__':
    main()
