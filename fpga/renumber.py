#!/usr/bin/env -S uv run --script
import re
import sys


def usage():
    print("Usage: ./renumber.py <input xdc file> <output xdc file>")

def main(args):
    if (len(args) != 2):
        usage()
        exit()

    probenum = 0
    countLines = 1

    with open(args[0]) as xdcfile, open(args[1], 'w') as outfile:
        Lines = xdcfile.readlines()
        for line in Lines:
            t = re.sub("probe[0-9]+", f"probe{probenum}",line)

            if line.find("probe") >= 0:
                countLines = countLines + 1

            if countLines == 4:
                countLines = 0
                probenum = probenum + 1

            outfile.write(t)



if __name__ == '__main__':
    main(sys.argv[1:])
