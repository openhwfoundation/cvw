#!/usr/bin/env -S uv run --script

###########################################
## CacheSim.py
##
## Written: lserafini@hmc.edu
## Created: 27 March 2023
## Modified: 12 April 2023
##
## Purpose: Simulate a L1 D$ or I$ for comparison with Wally
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https:##solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################

# how to invoke this simulator:
# CacheSim.py <number of lines> <number of ways> <length of physical address> <length of tag> -f <log file> (-v)
# so the default invocation for rv64gc is 'CacheSim.py 64 4 56 44 -f <log file>'
# the log files to run this simulator on can be generated from testbench.sv
# by setting I_CACHE_ADDR_LOGGER and/or D_CACHE_ADDR_LOGGER to 1 before running tests.
# I (Lim) recommend logging a single set of tests (such as wally64priv) at a time.
# This helps avoid unexpected logger behavior.
# With verbose mode off, the simulator only reports mismatches between its and Wally's behavior.
# With verbose mode on, the simulator logs each access into the cache.
# Add -p or --perf to report the hit/miss ratio.
# Add -d or --dist to report the distribution of loads, stores, and atomic ops.
# These distributions may not add up to 100; this is because of flushes or invalidations.

import argparse
import math
import os
import sys


class CacheLine:
    def __init__(self):
        self.tag = 0
        self.valid = False
        self.dirty = False

    def __str__(self):
        string = f"(V: {self.valid}, D: {self.dirty}"
        string += f", Tag: {hex(self.tag)})"
        return string

    def __repr__(self):
        return self.__str__()

class Cache:
    def __init__(self, numsets, numways, addrlen, taglen):
        self.numways = numways
        self.numsets = numsets

        self.addrlen = addrlen
        self.taglen = taglen
        self.setlen = int(math.log(numsets, 2))
        self.offsetlen = self.addrlen - self.taglen - self.setlen

        self.ways = []
        for i in range(numways):
            self.ways.append([])
            for _ in range(numsets):
                self.ways[i].append(CacheLine())

        self.pLRU = []
        for i in range(self.numsets):
            self.pLRU.append([0]*(self.numways-1))

    # flushes the cache by setting all dirty bits to False
    def flush(self):
        for way in self.ways:
            for line in way:
                line.dirty = False

    # access a cbo type instruction
    def cbo(self, addr, invalidate):
        tag, setnum, _ = self.splitaddr(addr)
        for waynum in range(self.numways):
            line = self.ways[waynum][setnum]
            if line.tag == tag and line.valid:
                line.dirty = 0
                if invalidate:
                    line.valid = 0

    # invalidates the cache by setting all valid bits to False
    def invalidate(self):
        for way in self.ways:
            for line in way:
                line.valid = False

    # resets the pLRU to a fresh 2-D array of 0s
    def clear_pLRU(self):
        self.pLRU = []
        for _ in range(self.numsets):
            self.pLRU.append([0]*(self.numways-1))

    # splits the given address into tag, set, and offset
    def splitaddr(self, addr):
        # no need for offset in the sim, but it's here for debug
        tag = addr >> (self.setlen + self.offsetlen) & int('1'*self.taglen, 2)
        setnum = (addr >> self.offsetlen) & int('1'*self.setlen, 2)
        offset = addr & int('1'*self.offsetlen, 2)
        return tag, setnum, offset

    # performs a cache access with the given address.
    # returns a character representing the outcome:
    # H/M/E/D - hit, miss, eviction, or eviction with writeback
    def cacheaccess(self, addr, write=False):
        tag, setnum, _ = self.splitaddr(addr)

        # check our ways to see if we have a hit
        for waynum in range(self.numways):
            line = self.ways[waynum][setnum]
            if line.tag == tag and line.valid:
                line.dirty = line.dirty or write
                self.update_pLRU(waynum, setnum)
                return 'H'

        # we didn't hit, but we may not need to evict.
        # check for an empty way line.
        for waynum in range(self.numways):
            line = self.ways[waynum][setnum]
            if not line.valid:
                line.tag = tag
                line.valid = True
                line.dirty = write
                self.update_pLRU(waynum, setnum)
                return 'M'

        # we need to evict. Select a victim and overwrite.
        victim = self.getvictimway(setnum)
        line = self.ways[victim][setnum]
        prevdirty = line.dirty
        line.tag = tag
        line.valid = True   # technically redundant
        line.dirty = write
        self.update_pLRU(victim, setnum)
        return 'D' if prevdirty else 'E'

    # updates the psuedo-LRU tree for the given set
    # with an access to the given way
    def update_pLRU(self, waynum, setnum):
        if self.numways == 1:
            return

        tree = self.pLRU[setnum]
        bottomrow = (self.numways - 1)//2
        index = (waynum // 2) + bottomrow
        tree[index] = int(not waynum % 2)
        while index > 0:
            parent = (index-1) // 2
            tree[parent] = index % 2
            index = parent

    # uses the psuedo-LRU tree to select
    # a victim way from the given set
    # returns the victim way as an integer
    def getvictimway(self, setnum):
        if self.numways == 1:
            return 0

        tree = self.pLRU[setnum]
        index = 0
        bottomrow = (self.numways - 1) // 2 #first index on the bottom row of the tree
        while index < bottomrow:
            if tree[index] == 0:
                # Go to the left child
                index = index*2 + 1
            else: #tree[index] == 1
                # Go to the right child
                index = index*2 + 2

        victim = (index - bottomrow)*2
        if tree[index] == 1:
            victim += 1

        return victim

    def __str__(self):
        string = ""
        for i in range(self.numways):
            string += f"Way {i}: "
            for line in self.ways[i]:
                string += f"{line}, "
            string += "\n\n"
        return string

    def __repr__(self):
        return self.__str__()


def parseArgs():
    parser = argparse.ArgumentParser(description="Simulates a L1 cache.")
    parser.add_argument('numlines', type=int, help="The number of lines per way (a power of 2)", metavar="L")
    parser.add_argument('numways', type=int, help="The number of ways (a power of 2)", metavar='W')
    parser.add_argument('addrlen', type=int, help="Length of the address in bits (a power of 2)", metavar="A")
    parser.add_argument('taglen', type=int, help="Length of the tag in bits", metavar="T")
    parser.add_argument('-f', "--file", required=True, help="Log file to simulate from")
    parser.add_argument('-v', "--verbose", action='store_true', help="verbose/full-trace mode")
    parser.add_argument('-p', "--perf", action='store_true', help="Report hit/miss ratio")
    parser.add_argument('-d', "--dist", action='store_true', help="Report distribution of operations")
    return parser.parse_args()

def main(args):
    cache = Cache(args.numlines, args.numways, args.addrlen, args.taglen)
    extfile = os.path.expanduser(args.file)
    mismatches = 0

    if args.perf:
        hits = 0
        misses = 0

    if args.dist:
        loads = 0
        stores = 0
        atoms = 0
        totalops = 0

    with open(extfile) as f:
        for ln in f:
            ln = ln.strip()
            lninfo = ln.split()
            if len(lninfo) < 3: #non-address line
                if len(lninfo) > 0 and (lninfo[0] == 'BEGIN' or lninfo[0] == 'TRAIN'):
                    # currently BEGIN and END traces aren't being recorded correctly
                    # trying TRAIN clears instead
                    cache.invalidate() # a new test is starting, so 'empty' the cache
                    cache.clear_pLRU()
                    if args.verbose:
                        print("New Test")

            else:
                if args.dist:
                    totalops += 1

                if lninfo[1] == 'F':
                    cache.flush()
                    if args.verbose:
                        print("F")
                elif lninfo[1] == 'I':
                    cache.invalidate()
                    if args.verbose:
                        print("I")
                elif lninfo[1] == 'V' or lninfo[1] == 'L' or lninfo[1] == 'C':
                    addr = int(lninfo[0], 16)
                    IsCBOClean = lninfo[1] != 'C'
                    cache.cbo(addr, IsCBOClean)
                    if args.verbose:
                        print(lninfo[1])
                else:
                    addr = int(lninfo[0], 16)
                    iswrite = lninfo[1] == 'W' or lninfo[1] == 'A' or lninfo[1] == 'Z'
                    result = cache.cacheaccess(addr, iswrite)

                    if args.verbose:
                        tag, setnum, offset = cache.splitaddr(addr)
                        print(hex(addr), hex(tag), hex(setnum), hex(offset), lninfo[2], result)

                    if args.perf:
                        if result == 'H':
                            hits += 1
                        else:
                            misses += 1

                    if args.dist:
                        if lninfo[1] == 'R':
                            loads += 1
                        elif lninfo[1] == 'W':
                            stores += 1
                        elif lninfo[1] == 'A':
                            atoms += 1

                    if result != lninfo[2]:
                        print(f"Result mismatch at address {lninfo[0]}. Wally: {lninfo[2]}, Sim: {result}")
                        mismatches += 1
    if args.dist:
        percent_loads = str(round(100*loads/totalops))
        percent_stores = str(round(100*stores/totalops))
        percent_atoms = str(round(100*atoms/totalops))
        print(f"This log had {percent_loads}% loads, {percent_stores}% stores, and {percent_atoms}% atomic operations.")

    if args.perf:
        ratio = round(hits/misses,3)
        print("There were", hits, "hits and", misses, "misses. The hit/miss ratio was", str(ratio)+".")

    if mismatches == 0:
        print("SUCCESS! There were no mismatches between Wally and the sim.")
    return mismatches

if __name__ == '__main__':
    args = parseArgs()
    sys.exit(main(args))
