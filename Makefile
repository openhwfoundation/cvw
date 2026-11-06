# David_Harris@hmc.edu 2023
# Top-level Makefile for CORE-V-Wally
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

MAKEFLAGS += --output-sync --no-print-directory

SIM = ${WALLY}/sim

.PHONY: all act periph testfloat zsbl coverage sim_bp deriv clean

all: act periph testfloat zsbl coverage sim_bp deriv

# act builds the riscv-arch-test suite for every cvw configuration that has an ACT test-generation
# configuration (config/<cfg>/act/test_config.yaml, owned by cvw; see bin/actconfig-sync)
ACTDIR ?= ${WALLY}/addins/riscv-arch-test
ACT_CONFIGS = $(wildcard ${WALLY}/config/*/act/test_config.yaml)
# ACT builds each configuration's ELFs in work/<name>, where <name> is cvw-<cfg> from the configuration's yaml
ACT_WORKDIRS = $(patsubst ${WALLY}/config/%/act/test_config.yaml,$(ACTDIR)/work/cvw-%,$(ACT_CONFIGS))
act: $(ACT_WORKDIRS:%=%/.cvw_config_stamp)
	$(MAKE) -C $(ACTDIR) CONFIG_FILES="$(ACT_CONFIGS)"

# ACT's incremental build never deletes ELFs, so the ELFs of tests that a changed configuration no longer
# supports would be left behind and still run.  When a configuration's files change, discard its ELFs so
# that ACT rebuilds exactly the current set.
.SECONDEXPANSION:
$(ACTDIR)/work/cvw-%/.cvw_config_stamp: $$(wildcard ${WALLY}/config/$$*/act/*)
	rm -rf $(@D)/elfs
	mkdir -p $(@D)
	touch $@

# periph builds the self-checking peripheral tests
periph:
	$(MAKE) -C tests/periph

testfloat:
	$(MAKE) -C ${WALLY}/tests/fp vectors

zsbl:
	$(MAKE) -C ${WALLY}/fpga/zsbl

coverage:
	$(MAKE) -C tests/coverage
	$(MAKE) -C tests/coverage32

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
	$(MAKE) clean -C ${WALLY}/tests/coverage32
	$(MAKE) clean -C ${WALLY}/tests/periph
	rm -rf $(ACT_WORKDIRS)
