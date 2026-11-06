# CoreMark on CORE-V-Wally
# Daniel Torres & David Harris 28 July 2022
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Builds the common CoreMark port (build.sh, also used for the other cores in docs/comparison.adoc)
# with the configuration's riscv-arch-test link.ld and rvmodel_macros.h, and runs it on wsim.
# -DWALLY_HPM adds CORE-V-Wally's performance-counter report for coremark_sweep.py.

XLEN ?= 32
CONFIG ?= rv$(XLEN)gc
ARCH ?= rv$(XLEN)im_zicsr_zba_zbb_zbc_zbs
ABI ?= $(if $(filter 64,$(XLEN)),lp64,ilp32)
ITERATIONS ?= 10
# Derived configurations have no act directory; rv64gc's files serve every configuration
ACTDIR ?= $(firstword $(wildcard $(WALLY)/config/$(CONFIG)/act) $(WALLY)/config/rv64gc/act)
work_dir = $(CURDIR)/build/$(CONFIG)-$(ARCH)
elf = $(work_dir)/coremark.elf

all: $(elf)

# pipefail, so that a failing simulation fails the make rather than being hidden by tee
run: SHELL := /bin/bash
run: .SHELLFLAGS := -o pipefail -c
run: $(elf)
	time wsim --sim verilator $(CONFIG) $(elf) 2>&1 | tee $(work_dir)/coremark.sim.log

$(elf): build.sh crt.S core_portme.c core_portme.h ee_printf.c Makefile
	OUT=$(work_dir) ./build.sh $(CONFIG) $(ACTDIR) $(ARCH) $(ABI) $(ITERATIONS) -DWALLY_HPM
	riscv64-unknown-elf-objdump -D $@ > $@.objdump

.PHONY: all run clean

clean:
	rm -rf build
