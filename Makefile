# David_Harris@hmc.edu 2023
# Top-level Makefile for CORE-V-Wally
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

MAKEFLAGS += --output-sync --no-print-directory

SIM = ${WALLY}/sim

.PHONY: all act periph testfloat zsbl coverage sim_bp deriv clean

all: act periph testfloat zsbl coverage sim_bp deriv

# act builds the riscv-arch-test suite for every cvw configuration that has an ACT test-generation
# configuration (config/<cfg>/act/test_config.yaml, owned by cvw; see bin/actconfig-sync)
ACTDIR = ${WALLY}/addins/riscv-arch-test
ACT_CONFIGS = $(wildcard ${WALLY}/config/*/act/test_config.yaml)
act:
	$(MAKE) -C $(ACTDIR) EXTENSIONS= CONFIG_FILES="$(ACT_CONFIGS)"

# periph builds the self-checking peripheral tests
periph:
	$(MAKE) -C tests/periph

testfloat:
	$(MAKE) -C ${WALLY}/tests/fp vectors

zsbl:
	$(MAKE) -C ${WALLY}/fpga/zsbl

coverage:
	$(MAKE) -C tests/coverage

deriv:
	derivgen.pl

sim_bp: ${WALLY}/addins/branch-predictor-simulator/src/sim_bp

${WALLY}/addins/branch-predictor-simulator/src/sim_bp:
	$(MAKE) -C ${WALLY}/addins/branch-predictor-simulator/src

# Requires a license for the Breker tool. See tests/breker/README.md for details
breker:
	$(MAKE) -C ${WALLY}/testbench/trek_files
	$(MAKE) -C ${WALLY}/tests/breker

clean:
	$(MAKE) clean -C ${WALLY}/tests/fp
	$(MAKE) clean -C ${WALLY}/fpga/zsbl
	$(MAKE) clean -C ${WALLY}/tests/coverage
	$(MAKE) clean -C ${WALLY}/tests/periph
