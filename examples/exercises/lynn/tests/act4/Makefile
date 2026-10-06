# tests/act4/Makefile
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26

RISCV_ARCH_TEST ?= $(WALLY)/addins/riscv-arch-test-cvw

WORK_DIR        ?= $(CURDIR)/work
STAMP           := $(WORK_DIR)/copy_stamp

ELFS_DIR 		?= $(WORK_DIR)/lynn-rv32I/elfs/rv32i

CONFIG_FILES 	?=

.PHONY: populate
populate: $(STAMP)

$(STAMP): Makefile
	@mkdir -p $(WORK_DIR)
	@$(MAKE) -C $(RISCV_ARCH_TEST) \
		CONFIG_FILES=$(CONFIG_FILES) \
		WORKDIR=$(WORK_DIR) \
		--jobs $$(nproc)
	@rm -rf $(ELFS_DIR)/Zicsr
	@rm -f  $(ELFS_DIR)/Zicntr/*csrrc*
	@rm -f  $(ELFS_DIR)/Zihpm/*csrrc*
	@touch $(STAMP)

.PHONY: list-elfs
list-elfs:
	@find -L $(ELFS_DIR) -type f -name '*.elf' | sort

.PHONY: clean
clean:
	rm -rf $(WORK_DIR)
