# Jordan Carlin, jcarlin@hmc.edu, August 2024
# Floating Point Tests Makefile for CORE-V-Wally
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

MAKEFLAGS += --output-sync --no-print-directory

SOFTFLOAT_DIR := ${WALLY}/addins/berkeley-softfloat-3/build/Linux-x86_64-GCC
TESTFLOAT_DIR := ${WALLY}/addins/berkeley-testfloat-3/build/Linux-x86_64-GCC
COVERFLOAT_DIR := ${WALLY}/addins/cover-float
COVERFLOAT_TV  := ${COVERFLOAT_DIR}/tests/testvectors
COVERFLOAT_OUT := ${WALLY}/tests/fp/coverfloat

.PHONY: all softfloat testfloat vectors coverfloat clean

all: vectors

softfloat: ${SOFTFLOAT_DIR}/softfloat.a

testfloat: ${TESTFLOAT_DIR}/testfloat_gen

vectors: testfloat
	$(MAKE) -C ${WALLY}/tests/fp/vectors

# cover-float (addins/cover-float) generates its vectors in its own tests/testvectors, regenerating only the
# models whose generator changed (AGGRESSIVENESS=0 generates its smaller set); bin/coverfloat2tv converts them
# into coverfloat/vectors, named like the TestFloat vectors, for testbench_fp +VECTORS=${COVERFLOAT_OUT}/vectors/.
# cover-float is its own uv project, so drop any VIRTUAL_ENV that would make uv warn about the mismatch.
coverfloat:
	[ -e ${COVERFLOAT_DIR}/src/dependencies/softfloat/spike/.git ] || \
	    git -C ${WALLY} submodule update --init --recursive addins/cover-float
	env -u VIRTUAL_ENV $(MAKE) -C ${COVERFLOAT_DIR} SILENT=True PROCESSED_ONLY=True
	$(MAKE) ${COVERFLOAT_OUT}/vectors/.stamp

${COVERFLOAT_OUT}/vectors/.stamp: $(wildcard ${COVERFLOAT_TV}/B*_tv.txt) ${WALLY}/bin/coverfloat2tv
	rm -rf ${COVERFLOAT_OUT}/vectors
	${WALLY}/bin/coverfloat2tv ${COVERFLOAT_OUT}/vectors ${COVERFLOAT_TV}/B*_tv.txt
	touch $@

clean:
	$(MAKE) -C ${WALLY}/tests/fp/vectors clean
	rm -rf ${COVERFLOAT_OUT}
	$(MAKE) -C ${COVERFLOAT_DIR} clean
	$(MAKE) -C ${SOFTFLOAT_DIR} clean
	$(MAKE) -C ${TESTFLOAT_DIR} clean

${SOFTFLOAT_DIR}/softfloat.a:
	$(MAKE) SPECIALIZE_TYPE=RISCV -C ${SOFTFLOAT_DIR}

${TESTFLOAT_DIR}/testfloat_gen: ${SOFTFLOAT_DIR}/softfloat.a
	$(MAKE) -C ${TESTFLOAT_DIR}
