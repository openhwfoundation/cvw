#!/usr/bin/env -S uv run --script

import fileinput
import sys

address = 0


with fileinput.input('-') as f:
    for line in f:
        # the 14- is to reverse the byte order to little endian
        formatedLine = ' '.join(line[14-i:14-i+2] for i in range(0, len(line), 2))
        sys.stdout.write(f'@{address:08x} {formatedLine:s}\n')
        address+=8
