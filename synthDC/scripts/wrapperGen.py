#!/usr/bin/env -S uv run --script
"""
wrapperGen.py

kekim@hmc.edu

script that generates top-level wrappers for verilog modules to synthesize
"""

import argparse
import glob
import os

#create argument parser
parser = argparse.ArgumentParser()

parser.add_argument("DESIGN")
parser.add_argument("HDLPATH")

args=parser.parse_args()

fin_path = glob.glob(f"{os.getenv('WALLY')}/src/**/{args.DESIGN}.sv",recursive=True)[0]

with open(fin_path) as fin:
    lines = fin.readlines()

    # keeps track of what line number the module header begins
    lineModuleStart = 0

    # keeps track of what line number the module header ends
    lineModuleEnd = 0

    # keeps track of module name
    moduleName = ""

    # string that will keep track of the running module header
    buf = 'import cvw::*;\n`include "config.vh"\n`include "parameter-defs.vh"\n'

    # are we writing into the buffer
    writeBuf=False

    index=0

    # string copy logic
    for l in lines:
        if l.lstrip().find("module") == 0:
            lineModuleStart = index
            moduleName = l.split()[1]
            writeBuf = True
            buf += f"module {moduleName}wrapper (\n"
            continue
        if (writeBuf):
            buf += l
        if l.lstrip().find (");") == 0:
            lineModuleEnd = index
            break
        index+=1

    # post-processing buffer: add DUT and endmodule lines
    buf += f"\t{moduleName} #(P) dut(.*);\nendmodule"

    # path to wrapper
    wrapperPath = f"{args.HDLPATH}/{moduleName}wrapper.sv"

    with open(wrapperPath, "w") as fout:
        fout.write(buf)
