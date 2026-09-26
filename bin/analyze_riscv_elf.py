#!/usr/bin/env -S uv run --script

###########################################
## analyze_riscv_elf.py
##
## Written: james.stine@okstate.edu
## Created: April 7, 2025
##
## Purpose: Analyze a RISC-V ELF file and report which instructions are used,
##          along with their frequency. The script disassembles the ELF using
##          riscv64-unknown-elf-objdump, filters real instructions (excluding
##          pseudo-ops and section headers), and displays a histogram of
##          instruction use.
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
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

import re
import subprocess
import sys
from collections import Counter


def disassemble_elf(elf_path):
    try:
        result = subprocess.run(
            ["riscv64-unknown-elf-objdump", "-d", "-M", "no-aliases", elf_path],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running objdump: {e.stderr}")
        sys.exit(1)

def extract_instructions(disassembly):
    instructions = []
    for line in disassembly.splitlines():
        # Match instruction lines only: address: machine-code instruction [operands...]
        match = re.match(r'^\s*[0-9a-f]+:\s+([0-9a-f]{8}|\s{8})\s+(\S+)', line)
        if match:
            instr = match.group(2)
            instructions.append(instr)
    return instructions

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 analyze_riscv_elf.py <file.elf>")
        sys.exit(1)

    elf_path = sys.argv[1]
    disassembly = disassemble_elf(elf_path)
    instructions = extract_instructions(disassembly)
    counter = Counter(instructions)

    print(f"\nInstruction usage in {elf_path}:\n")
    if not counter:
        print("No instructions found (did you use the correct target ELF file?)")
    else:
        for instr, count in counter.most_common():
            count_str = f"{count:,}"  # Add comma as thousands separator
            print(f"{instr:<10} {count_str}")

if __name__ == "__main__":
    main()
