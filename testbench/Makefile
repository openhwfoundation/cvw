# Makefile for testbench to create .memfile, .objdump.addr, and .objdump.lab from an ELF
# David_Harris@hmc.edu 3 July 2024
# james.stine@okstate.edu 24 Jan 2025
# jcarlin@hmc.edu 7 Jul 2025
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Write through a temporary file, so that a simulation running the same ELF in parallel never reads
# a partly written file
%.memfile: %
	elf2hex $< $@.$$$$ && mv $@.$$$$ $@

# The label maps list the ELF's symbols; regenerate them when the extraction script changes.  The
# testbench asks for the .addr map, so it is moved into place last: a parallel simulation that finds
# it up to date can then also open the .lab map
%.objdump.addr %.objdump.lab: % $(WALLY)/bin/extractFunctionRadix.sh
	extractFunctionRadix.sh $< $*.objdump.$$$$ && mv $*.objdump.$$$$.lab $*.objdump.lab && mv $*.objdump.$$$$.addr $*.objdump.addr
