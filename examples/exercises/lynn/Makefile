# Wally Coremark Makefile
# James Kaden Cassidy 1/1/2026 kacassidy@hmc.edu
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# ============================================================
#              Processor / Testbench Configuration
# ============================================================

# ---- Processor / Testbench Configuration ---- #
XLEN 				?= 32

PROCESSOR_DIR   	?= $(CURDIR)/sample_processor/src      # Directory containing all PROCESSOR RTL (will scan for .sv / .svh)
INC_DIR       		?= $(CURDIR)/sample_processor/incdir/  # Optional directory for include files for RTL compilation (parameters)

PROCESSOR_TOP 		?= riscvsingle # top-level module name
PROCESSOR_CONFIG 	?= $(CURDIR)/sample_processor/config

#--trace-all
SAIL_TRACE_FLAGS 	?= --trace-all

# ----    Synthesis Configuration ---- #
SYNTH_TECH 			?= sky130 #tsmc28 #tsmc28psyn
SYNTH_TOP 			?= $(PROCESSOR_TOP) # change to different module to find critical path of a specific module

# ----    Coremark Configuration ---- #

#ARCH := rv$(XLEN)im_zicsr_zba_zbb_zbs
#ARCH := rv$(XLEN)gc
#ARCH := rv$(XLEN)imc_zicsr
#ARCH := rv$(XLEN)im_zicsr
ARCH := rv$(XLEN)i_zicsr

# ---- Command line optional parameters ---- #
ELFS 				?=
GUI  				?= 0
SAIL  				?= 0
VSIM_EXTRA_FLAGS 	?= # Extra flags if you want them

# Optional extra plusargs you can add without touching the recipe
VSIM_PLUSARGS_EXTRA ?=

# ---- Command line optional parameters ---- #
# (moved to top knobs)

# ---- Repo paths ---- #
LINKER			?= $(PROCESSOR_CONFIG)/link.ld

TB_TOP          ?= testbench
TESTBENCH_FILES ?= $(TESTBENCH_DIR)/testbench.sv $(TESTBENCH_DIR)/ram1p1rwb.sv
WAVES_DO        ?= $(TESTBENCH_DIR)/waves.do

# ---- Repo paths cont ---- #
COREMARK_DIR 	?= $(CURDIR)/coremark
C_TEST_DIR		?= $(CURDIR)/tests/C
ACT4_TEST_DIR	?= $(CURDIR)/tests/act4
BRINGUP_TEST_DIR?= $(CURDIR)/tests/bringup
TESTBENCH_DIR 	?= $(CURDIR)/tb
SYNTH_DIR 		?= $(CURDIR)/synth

WORK_DIR        ?= $(CURDIR)/work
RISCV_ARCH_TEST ?= $(WALLY)/addins/riscv-arch-test-cvw

TEST_WORK_DIR	?= $(ACT4_TEST_DIR)/work
C_TEST_WORK_DIR ?= $(C_TEST_DIR)/work
CM_WORK_DIR		?= $(COREMARK_DIR)/work

# ----    Simulation Settings    ---- #
VSIM        	?= vsim
VSIM_FLAGS  	?= -voptargs=+acc

# ----    Tools    ---- #
PYTHON 		:= python3
SAIL_RUN   	:= sail_riscv_sim
TOOLPREFIX 	:= riscv64-unknown-elf-

# Derive tools from the prefix
CC      := $(TOOLPREFIX)gcc
OBJDUMP := $(TOOLPREFIX)objdump
READELF := $(TOOLPREFIX)readelf
SIZE    := $(TOOLPREFIX)size
ELF2HEX := elf2hex

# ----    Coremark Parameters ---- #
# (moved into coremark/Makefile)
ABI := $(if $(findstring "64","$(XLEN)"),lp64,ilp32)

# ----    Files and Directories    ---- #
SV_PACKAGES := $(sort $(shell find $(PROCESSOR_DIR) -type f -name '*.pkg'))
SV_SOURCES 	:= $(sort $(shell find $(PROCESSOR_DIR) -type f \( -name "*.sv" -o -name "*.svh" \)) $(shell find $(INC_DIR) -type f \( -name "*.sv" -o -name "*.svh" \)))
TEST_ELFS  	= $(sort $(shell find -L $(ACT4_TEST_DIR) -type f -name '*.elf'))

# ----          Targets            ---- #

# Default target: just build (compile RTL/testbench once)
all: build

.PHONY: lint
lint:
	@verilator --lint-only --quiet \
		--top-module $(PROCESSOR_TOP) \
		-DPROCESSOR_TOP=$(PROCESSOR_TOP) \
		-I$(abspath $(INC_DIR)) \
		$(abspath $(SV_PACKAGES) $(SV_SOURCES) $(TESTBENCH_FILES)) \
		-Wall -Wno-UNUSEDSIGNAL -Wno-VARHIDDEN -Wno-TIMESCALEMOD \
		&& echo "[LINT] Linting completed without errors."
# -Wno-DECLFILENAME -Wno-CASEX

# Build = compile RTL once into $(WORK_DIR)/build
.PHONY: build
$(WORK_DIR)/_info: $(SV_PACKAGES) $(SV_SOURCES) $(TESTBENCH_FILES) Makefile
	echo "[BUILD] Creating/using local 'work' library..." && \
	(vlib work 2>/dev/null || true) && \
	echo "[BUILD] Compiling SystemVerilog sources..." && \
	vlog -sv \
		+incdir+$(INC_DIR) \
		+define+PROCESSOR_TOP=$(PROCESSOR_TOP) \
		+define+XLEN=$(XLEN) $(abspath $(SV_PACKAGES) $(SV_SOURCES) $(TESTBENCH_FILES))
	@mkdir -p $(WORK_DIR)
	@touch $@

build: $(WORK_DIR)/_info Makefile

# ----  Generic memfile / run / test flow  ---- #

# Any file -> file.memfile
.PRECIOUS: %.memfile
%.memfile: %.elf
	@echo "[MEM] Generating memfile $@ from $< along with debug files"
	$(SIZE) -A $< > $<.size
	$(READELF) -S $< > $<.read
	$(OBJDUMP) -D $< > $<.objdump
	$(ELF2HEX) $< $@
	extractFunctionRadix.sh $<.objdump

#   Use: make run ELFS="path/to/a.elf path/to/b.elf" [-j]
.PHONY: run
run: $(addsuffix .run,$(basename $(ELFS)))

# Generate score for the project based on coremark score and timing
.PHONY: score
score:
	@$(PYTHON) $(CURDIR)/bin/score.py $(SYNTH_DIR)/work $(CM_WORK_DIR) --output-log $(CURDIR)/score.log

ifeq ($(SAIL),1)
RUNNER := sail
else
RUNNER := processor
endif

# foo.elf.run depends on foo.elf.memfile and build
%.run: %.$(RUNNER) Makefile
	@:

%.sail: %.elf Makefile
	$(SAIL_RUN) $< \
	--config $(PROCESSOR_CONFIG)/sail.json \
	$(SAIL_TRACE_FLAGS) \
	--trace-output $@.trace \
	 > $@.log 2>&1


# Build the vsim mode flags from GUI
ifeq ($(GUI),1)
  VSIM_MODE_FLAGS :=
  VSIM_DO := if {[file exists $(WAVES_DO)]} {do $(WAVES_DO)};
else
  VSIM_MODE_FLAGS := -c
  VSIM_DO := run -all; quit -f
endif

# VSIM plusargs in one place (shell vars, so they expand correctly inside %.processor)
VSIM_PLUSARGS_BASE  ?= \
	+TESTNAME="$$NAME" \
	+MEMFILE="$$MEMFILE" \
	+ENTRY_ADDR="$$ENTRY_ADDR" \
	+TOHOST_ADDR="$$TOHOST_ADDR" \
	+DMEM_BASE_ADDR="$$DMEM_BASE_ADDR"

%.processor: %.memfile $(WORK_DIR)/_info Makefile
	@set -e; \
	MEMFILE="$(abspath $<)"; \
	ELF="$${MEMFILE%.memfile}.elf"; \
	ENTRY_ADDR="$$(riscv64-unknown-elf-readelf -h "$$ELF" | awk '/Entry point address:/ {print $$NF}')"; \
	TOHOST_ADDR="$$(riscv64-unknown-elf-readelf --syms --wide "$$ELF" | awk '$$NF=="tohost" {print "0x"$$2; exit}')" \
	DMEM_BASE_ADDR="$$(riscv64-unknown-elf-readelf --syms --wide "$$ELF" | awk '$$NF=="dmem_base" {print "0x"$$2; exit}')" \
	NAME="$${ELF##*/}"; \
	LOGFILE="$${ELF}.sim.log"; \
	echo "[RUN] ELF: $$ELF"; \
	echo "[VSIM] Using memfile $$MEMFILE (log: $$LOGFILE)"; \
	$(VSIM) $(VSIM_MODE_FLAGS) $(VSIM_FLAGS) $(VSIM_EXTRA_FLAGS) work.$(TB_TOP) \
		$(VSIM_PLUSARGS_BASE) $(VSIM_PLUSARGS_EXTRA) \
		-do "$(VSIM_DO)" \
		2>&1 | { [ "$(GUI)" = "1" ] && tee "$$LOGFILE" || cat >"$$LOGFILE"; }


.PHONY: synth
synth: lint
	$(MAKE) -C $(SYNTH_DIR) \
		SYNTH_TECH=$(SYNTH_TECH) PROCESSOR_DIR=$(PROCESSOR_DIR) INC_DIR=$(INC_DIR) \
		PROCESSOR_TOP=$(PROCESSOR_TOP) XLEN=$(XLEN) SYNTH_TOP=$(SYNTH_TOP)


# ----  C test flow  ---- #
# (build moved into tests/C/Makefile)

.PHONY: C_test
C_test:
	@$(MAKE) -C $(C_TEST_DIR) \
		XLEN=$(XLEN) ARCH="$(ARCH)" ABI=$(ABI) LINKER=$(LINKER) TOOLPREFIX=$(TOOLPREFIX) \
		$(C_TEST_DIR)/work/c_test.elf
	@$(MAKE) run ELFS="$(C_TEST_DIR)/work/c_test.elf"

# ----  Bringup test flow  ---- #
# (build moved into tests/bringup/Makefile)

.PHONY: bringup_test
bringup_test:
	@$(MAKE) -C $(BRINGUP_TEST_DIR) \
		XLEN=$(XLEN) ARCH="$(ARCH)" ABI=$(ABI) TOOLPREFIX=$(TOOLPREFIX)
	@$(MAKE) run ELFS="$(BRINGUP_TEST_DIR)/work/bringup.elf"

# ----  Coremark flow  ---- #
# (build moved into coremark/Makefile)

.PHONY: coremark
coremark:
	@$(MAKE) -C $(COREMARK_DIR) \
		XLEN=$(XLEN) ARCH="$(ARCH)" ABI=$(ABI) LINKER=$(LINKER) TOOLPREFIX=$(TOOLPREFIX)
	@$(MAKE) run ELFS="$(COREMARK_DIR)/work/coremark.bare.riscv.elf"

# ---- Act4 flow ---- #
# (population moved into tests/act4/Makefile)

.PHONY: act4
act4:
	@$(MAKE) -C $(ACT4_TEST_DIR) \
		RISCV_ARCH_TEST=$(RISCV_ARCH_TEST) \
		CONFIG_FILES=$(PROCESSOR_CONFIG)/test_config.yaml \
		populate

# test: run ALL .elf files in ACT4_TEST_DIR in parallel with -j
.PHONY: test
test: | act4
	@echo "CURDIR=$(CURDIR)"
	@echo "ACT4_TEST_DIR=$(ACT4_TEST_DIR)"
	@$(MAKE) run ELFS="$$( $(MAKE) -s -C $(ACT4_TEST_DIR) list-elfs )"
	@cd $(ACT4_TEST_DIR) && $(PYTHON) ../../bin/scan_test_logs.py --sail $(SAIL)

%.bin: %.hex
	@sed -E 's/^[[:space:]]*#[[:space:]]*//; s/^[[:space:]]+//; /^[[:space:]]*$$/d' $< | \
	$(PYTHON) -c 'import sys,struct; \
	[sys.stdout.buffer.write(struct.pack("<I", int(l.strip(),16))) for l in sys.stdin if l.strip()]' \
	> $@

%.dis: %.bin
	@riscv64-unknown-elf-objdump -D -b binary -m riscv:rv32 $< > $@
	@echo "Wrote $@"

# ----  Bug lab  ---- #

.PHONY: bug
bug:
	$(CURDIR)/bug_scripts/bugall_riscvsingle.sh

# ----            Clean             ---- #

.PHONY: clean, clean-act4, clean-coremark, clean-synth

clean:
	$(MAKE) -C $(C_TEST_DIR) clean
	$(MAKE) -C $(BRINGUP_TEST_DIR) clean
	rm -rf $(WORK_DIR)
	rm -f score.log

clean-coremark:
	$(MAKE) -C $(COREMARK_DIR) clean

clean-act4:
	$(MAKE) -C $(ACT4_TEST_DIR) clean

clean-synth:
	$(MAKE) -C $(SYNTH_DIR) clean

clean-all: clean clean-act4 clean-synth clean-coremark
