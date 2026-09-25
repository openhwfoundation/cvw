# Verilator Makefile for WALLY
# Kunlin Han, Rose Thompson, David Harris 2024
# Jordan Carlin 2026
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

SHELL := /bin/bash
.PHONY: compile clean

# ------ Configuration variables (overridden by wsim) ------
WALLYCONF  ?= rv64gc        # Wally configuration (e.g. rv64gc, rv32i)
TESTBENCH  ?= testbench     # Top-level testbench module (testbench or testbench_fp)
PARAM_ARGS  =               # Compile-time parameter overrides (e.g. MAKE_VCD=1)
DEFINE_ARGS =               # Compile-time defines (e.g. +define+USE_IMPERAS_DV)
BUILD_HASH ?=               # Hash suffix for workdir when PARAM_ARGS/DEFINE_ARGS vary;
                            # computed by wsim to avoid shell-escaping issues in Make

# ------ Verilator flags ------
VERILATOR_FLAGS = --assert --no-trace-top --stats

# Compiling the generated C++ dominates the build, and Verilator does it serially by default.
JOBS ?= $(shell nproc)

# Waveform tracing generates a large amount of extra C++, so only build it when a VCD is wanted.
# wsim sets MAKE_VCD=1 for --vcd and keys the work directory on the parameters, so the traced and
# untraced builds do not collide.
ifneq ($(filter MAKE_VCD=1,$(PARAM_ARGS)),)
    VERILATOR_FLAGS += --trace
endif

# ------ Paths ------
VERILATOR_DIR = ${WALLY}/sim/verilator
INCLUDE_PATH  = "-I${WALLY}/config/shared" "-I${WALLY}/config/$(WALLYCONF)" "-I${WALLY}/config/deriv/$(WALLYCONF)"
SOURCES       = ${WALLY}/src/cvw.sv ${WALLY}/testbench/${TESTBENCH}.sv ${WALLY}/testbench/common/*.sv \
                ${WALLY}/src/*/*.sv ${WALLY}/src/*/*/*.sv \
                ${WALLY}/addins/verilog-ethernet/*/*.sv ${WALLY}/addins/verilog-ethernet/*/*/*/*.sv

# Convert PARAM_ARGS entries (e.g. "MAKE_VCD=1") into verilator -G flags (e.g. "-GMAKE_VCD=1")
EXPANDED_PARAM_ARGS := $(patsubst %,-G%,$(PARAM_ARGS))

# ------ Work directory ------
# Keyed on config + testbench (+ optional hash when compile-time params differ).
# Multiple test suites sharing the same config reuse a single compiled binary.
# wsim handles freshness checking and flock serialization before invoking make.
ifneq ($(BUILD_HASH),)
    WORKDIR = $(VERILATOR_DIR)/wkdir/$(WALLYCONF)_$(TESTBENCH)_$(BUILD_HASH)
else
    WORKDIR = $(VERILATOR_DIR)/wkdir/$(WALLYCONF)_$(TESTBENCH)
endif

# The regular testbench uses a C wrapper providing the getenvval DPI function
ifeq ($(TESTBENCH), testbench)
    WRAPPER = ${WALLY}/sim/verilator/wrapper.c
else
    WRAPPER =
endif

# ------ Targets ------

default: compile

compile:
	mkdir -p $(WORKDIR)
	verilator \
	--Mdir $(WORKDIR) -o V${TESTBENCH} \
	--binary -j $(JOBS) \
	$(VERILATOR_FLAGS) \
	--top-module ${TESTBENCH}  --relative-includes \
	$(INCLUDE_PATH) \
	${WRAPPER} \
	${DEFINE_ARGS} \
	${EXPANDED_PARAM_ARGS} \
	$(SOURCES)

clean:
	rm -rf $(VERILATOR_DIR)/wkdir $(VERILATOR_DIR)/logs
