# Makefile for testbench to create .memfile, .objdump.addr, and .objdump.lab from an ELF
# David_Harris@hmc.edu 3 July 2024
# james.stine@okstate.edu 24 Jan 2025
# jcarlin@hmc.edu 7 Jul 2025
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

%.memfile: %
	elf2hex $< $@

%.objdump.addr: %.objdump
	extractFunctionRadix.sh $<

%.objdump: %
	riscv64-unknown-elf-objdump -S -D $< > $@
