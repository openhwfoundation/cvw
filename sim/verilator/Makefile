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
LOCKSTEP   ?= 0             # 1 compiles in ImperasDV for lock-step comparison (wsim --lockstep)
SPEED_OPT  ?= 0             # 1 for long runs (wsim sets it for Linux boots): lock step then uses two threads

# ------ Verilator flags ------
VERILATOR_FLAGS = --assert --no-trace-top --stats

# Verilator compiles the generated C++ with -Os by default.  -O2 makes the rv64gc model 10-15% faster
# (CoreMark, ACT tests, and Linux boots) for 10-20% more compile CPU time.  -O3, with or without
# Verilator's own -O3, is slower than -O2.
VERILATOR_FLAGS += --MAKEFLAGS OPT_FAST=-O2 --MAKEFLAGS OPT_SLOW=-O1 --MAKEFLAGS OPT_GLOBAL=-O2

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

# Lockstep (wsim --lockstep) compiles in ImperasDV's RVVI and IDV SystemVerilog packages and links the
# ImperasDV DPI library, as -sv_lib does for Questa and VCS.  The library looks up the DPI scope
# functions (svGetScope, svSetScope, ...) in the executable at run time, so the executable must export its
# dynamic symbols (-rdynamic).  IMPERAS_VLNV selects the RISC-V model the library loads at run time.
# ImperasDV Y-2026.09's rvviTrace.sv initializes client_id_next in its declaration, and Verilator runs that
# initializer after the RVVI clients register, so no client gets the interrupt nets; wsim warns about it.
ifeq ($(strip $(LOCKSTEP)),1)
    IDV_LIB = $(IMPERAS_HOME)/lib/Linux64/ImperasLib/imperas.com/verification/riscv/1.0
    INCLUDE_PATH += "-I$(IMPERAS_HOME)/ImpPublic/include/host" "-I$(IMPERAS_HOME)/ImpPublic/include/host/rvvi" \
                    "-I$(IMPERAS_HOME)/ImpProprietary/include/host" "-I$(IMPERAS_HOME)/ImpProprietary/include/host/idv"
    LOCKSTEP_SOURCES = $(IMPERAS_HOME)/ImpPublic/source/host/rvvi/rvviApiPkg.sv \
                       $(sort $(wildcard $(IMPERAS_HOME)/ImpProprietary/source/host/idv/*.sv))
    # With functional coverage, riscv-arch-test's rvviTrace.sv takes the place of ImperasDV's
    ifneq ($(strip $(FCOV)),1)
        LOCKSTEP_SOURCES += $(IMPERAS_HOME)/ImpPublic/source/host/rvvi/rvviTrace.sv
    endif
    SOURCES := $(LOCKSTEP_SOURCES) $(SOURCES)
    VERILATOR_FLAGS += -LDFLAGS "-rdynamic -L$(IDV_LIB) -l:model.so -Wl,-rpath,$(IDV_LIB) -Wl,-rpath,$(IMPERAS_HOME)/bin/Linux64"
    # A second thread runs the ImperasDV calls (reference model step and compare) alongside the design,
    # which makes a lock-step Linux boot about 1.5x faster; four threads gain only 7% more, and the design
    # alone gains nothing from threads.  Only long runs (wsim sets SPEED_OPT=1 for Linux boots) use it, so that
    # parallel regressions of short tests keep one core per simulation.
    ifeq ($(strip $(SPEED_OPT)),1)
        VERILATOR_FLAGS += --threads 2
    endif
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
