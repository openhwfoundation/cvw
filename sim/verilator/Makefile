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
FCOV       ?= 0             # 1 compiles in the riscv-arch-test covergroups (wsim --fcov)

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
                ${WALLY}/src/*/*.sv ${WALLY}/src/*/*/*.sv
# Only the synthesizable RVVI interface (wsim --rvvi) uses the verilog-ethernet MAC
ifneq ($(findstring RVVI_SYNTH_SUPPORTED=1,$(PARAM_ARGS)),)
    SOURCES += ${WALLY}/addins/verilog-ethernet/*/*.sv ${WALLY}/addins/verilog-ethernet/*/*/*/*.sv
endif

# Functional coverage comes from riscv-arch-test: riscv_arch_test.sv instantiates the generated
# covergroups and samples them off the RVVI trace.  It needs four include paths: its own sources,
# the generated coverpoints, the test environment for derived_config.svh, and the env directory of
# the matching ACT configuration (cvw-<config>) for the generated rvtest_config.svh and
# rvmodel_macros.svh.  wsim passes +define+FCOV and a +define+<GROUP>_COVERAGE for each covergroup
# in DEFINE_ARGS, and names the coverage file at run time.
ifeq ($(strip $(FCOV)),1)
    ACT_DIR = ${WALLY}/addins/riscv-arch-test
    FCOV_SRC = $(ACT_DIR)/framework/src/act/fcov
    # riscv-arch-test's covergroups still draw Verilator warnings, which are not Wally's to fix, so
    # report them without stopping the build.  Some bin arrays sweep more values than Verilator's
    # default limit of 1024 (e.g. all 2^14 compressed encodings), so raise the limit to keep them.
    VERILATOR_FLAGS += --coverage-user --coverage-max-bins 16384 -Wno-fatal
    INCLUDE_PATH += "-I$(FCOV_SRC)" "-I$(ACT_DIR)/coverpoints" "-I$(ACT_DIR)/coverpoints/unpriv" \
                    "-I$(ACT_DIR)/coverpoints/priv" "-I$(ACT_DIR)/tests/env" \
                    "-I$(ACT_DIR)/work/cvw-$(strip $(WALLYCONF))/env"
    SOURCES := $(FCOV_SRC)/rvviTrace.sv $(FCOV_SRC)/riscv_arch_test.sv $(SOURCES)
endif

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
