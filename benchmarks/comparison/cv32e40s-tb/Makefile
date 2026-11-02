# Verilator build of the cv32e40s-tb core testbench (adapted from cv32e40x-dv tb/core).
# usage: make CFG=<rv32imc|rv32imcb-pma-pmp> [CV32E40S=<cv32e40s checkout>] [VERILATOR=<path>]
# Produces build/<CFG>/Vtb_top; run ELFs with bin/run-cv32e40s.sh --cfg <CFG> --elf <elf>.
TB_DIR    := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CV32E40S  ?= $(error set CV32E40S to an openhwfoundation/cv32e40s checkout at 9d9cae78b01a11458953133d1173c61933a2ba86)
VERILATOR ?= verilator
CFG       ?= rv32imc
OBJ       := $(TB_DIR)/build/$(CFG)

# riscv-arch-test config name (config/cores/cve4/cv32e40s-<CFG>) -> core parameters
CFG_DEFINES_rv32imc          :=
CFG_DEFINES_rv32imcb-pma-pmp := +define+CV32E40S_RVB +define+CV32E40S_PMA +define+CV32E40S_PMP
ifeq ($(origin CFG_DEFINES_$(CFG)),undefined)
  $(error unknown CFG=$(CFG); use rv32imc or rv32imcb-pma-pmp)
endif

export DESIGN_RTL_DIR := $(CV32E40S)/rtl
TB_SRC := $(TB_DIR)/tb/tb_riscv/include/perturbation_defines.sv \
          $(TB_DIR)/tb/tb_top.sv $(TB_DIR)/tb/cv32e40s_tb_wrapper.sv \
          $(TB_DIR)/tb/tb_riscv/riscv_rvalid_stall.sv $(TB_DIR)/tb/tb_riscv/riscv_gnt_stall.sv \
          $(TB_DIR)/tb/mm_ram.sv $(TB_DIR)/tb/dp_ram.sv
RTL_SRC := $(wildcard $(CV32E40S)/rtl/*.sv $(CV32E40S)/rtl/include/*.sv $(CV32E40S)/bhv/*.sv)

all: $(OBJ)/Vtb_top

# Flags follow cv32e40x-dv sim/core/Makefile (certify target)
$(OBJ)/Vtb_top: $(TB_SRC) $(RTL_SRC) $(TB_DIR)/Makefile
	mkdir -p $(OBJ)
	$(VERILATOR) --cc --sv --exe --build --main --timing -j 0 \
		--Wno-lint --Wno-UNOPTFLAT --Wno-MODDUP --Wno-BLKANDNBLK --Wno-COMBDLY --Wno-SYMRSVDWORD \
		--x-assign unique --x-initial unique +define+COREV_ASSERT_OFF \
		--top-module tb_top \
		-f $(CV32E40S)/cv32e40s_manifest.flist $(TB_SRC) $(CFG_DEFINES_$(CFG)) \
		--Mdir $(OBJ) -CFLAGS "-std=gnu++14 -O2"
	@echo "cv32e40s RTL: $$(git -C $(CV32E40S) rev-parse HEAD)  CFG=$(CFG)" > $(OBJ)/BUILD_INFO
	@$(VERILATOR) --version >> $(OBJ)/BUILD_INFO

clean:
	rm -rf $(TB_DIR)/build/$(CFG)

.PHONY: all clean
