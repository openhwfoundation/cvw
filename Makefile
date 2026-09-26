# David_Harris@hmc.edu 2023
# Top-level Makefile for CORE-V-Wally
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

MAKEFLAGS += --output-sync --no-print-directory

SIM = ${WALLY}/sim

.PHONY: all act riscof testfloat combined_IF_vectors zsbl coverage sim_bp deriv clean

all: act riscof	testfloat combined_IF_vectors zsbl coverage sim_bp deriv

# act builds the riscv-arch-test suite using the testgen generator
ACTDIR = ${WALLY}/addins/riscv-arch-test-cvw
act:
	$(MAKE) -C $(ACTDIR) EXTENSIONS= CONFIG_FILES="$(ACTDIR)/config/cores/cvw/cvw-rv32gc/test_config.yaml $(ACTDIR)/config/cores/cvw/cvw-rv64gc/test_config.yaml"

# riscof builds the riscv-arch-test and wally-riscv-arch-test suites
riscof:
	$(MAKE) -C tests/riscof

testfloat:
	$(MAKE) -C ${WALLY}/tests/fp vectors

combined_IF_vectors: testfloat riscof
	$(MAKE) -C ${WALLY}/tests/fp combined_IF_vectors

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
	$(MAKE) clean -C ${WALLY}/tests/riscof
	$(MAKE) clean -C ${WALLY}/tests/fp
	$(MAKE) clean -C ${WALLY}/fpga/zsbl
	$(MAKE) clean -C ${WALLY}/tests/coverage
