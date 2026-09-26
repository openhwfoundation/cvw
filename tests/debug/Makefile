###############################################################################
#  WALLY Debug Build System
#  -------------------------------------------------------------
#  Description :  Makefile for building and generating testvectors
#                 for the WALLY RISC-V System-on-Chip (SoC) debug flow.
#
#  Authors      :  Jacob Pease and James E. Stine
#
#  License      :  Open-source educational use permitted.
#                  Developed as part of the WALLY RISC-V SoC ecosystem.
#
#  Notes        :  This Makefile supports both RV32 and RV64 configurations.
#                  Ensure RISCV and WALLY environment variables are properly set.
#                  Invoke with:
#                      make all       – build ELF files, dumps, and testvectors
#                      make memfile   – generate memory files for simulation
#                      make clean     – remove build artifacts
#
#  Last Updated :  $(shell date +"%Y-%m-%d")
###############################################################################

# Check for $WALLY environment variable
ifndef WALLY
$(error WALLY is not set. Source setup.sh in your local cvw, and then run make)
endif

RISCV ?= /opt/riscv

CC = riscv64-unknown-elf-gcc
AS = riscv64-unknown-elf-as
LD = riscv64-unknown-elf-ld

OBJDUMP = riscv64-unknown-elf-objdump
LDSCRIPT := ./link.ld

# --------------------------------------------------------------------
# 64 bit stuff
# --------------------------------------------------------------------
SOURCE := $(shell find ./rv64 -type f -name "*.S")
BASENAMES := $(basename $(notdir $(SOURCE)))

# Build directories
BUILD := build
LOGSDIR := $(BUILD)/log
TVBUILDDIR := $(BUILD)/testvectors

# RV64
MARCH = -march=rv64gc_zicsr_zifencei
MABI = -mabi=lp64
ASFLAGS := $(MARCH) $(MABI) -mcmodel=medany -nostartfiles -L $(RISCV)/riscv64-unknown-elf/lib -T$(LDSCRIPT)

# 64 bit targets
TARGET      := $(addsuffix .elf, $(addprefix $(BUILD)/, $(BASENAMES)))
TARGETDUMPS := $(addsuffix .elf.objdump, $(addprefix $(BUILD)/, $(BASENAMES)))
TESTVECTORS := $(addsuffix .tv, $(addprefix $(TVBUILDDIR)/, $(BASENAMES)))

# --------------------------------------------------------------------
# 32 bit
# --------------------------------------------------------------------
SOURCE32 := $(shell find ./rv32 -type f -name "*.S")
BASENAMES32 := $(basename $(notdir $(SOURCE32)))

# 32-bit build directory
BUILD32      := build32
LOGSDIR32    := $(BUILD32)/log
TVBUILDDIR32 := $(BUILD32)/testvectors

# RV32
MARCH32 = -march=rv32imfdc_zicsr_zifencei
MABI32 = -mabi=ilp32
ASFLAGS32 := $(MARCH32) $(MABI32) -mcmodel=medany -nostartfiles -L $(RISCV)/riscv32-unknown-elf/lib -T$(LDSCRIPT)

# 32 bit
TARGET32       := $(addsuffix .elf, $(addprefix $(BUILD32)/, $(BASENAMES32)))
TARGETDUMPS32  := $(addsuffix .elf.objdump, $(addprefix $(BUILD32)/, $(BASENAMES32)))
TESTVECTORS32  := $(addsuffix .tv, $(addprefix $(TVBUILDDIR32)/, $(BASENAMES32)))

# Tcl code
TVDIR := testvectors

.PHONY: all all32 all64 build clean generate generate32 dirs debug memfile \
        sim32 sim64 debug32 debug64 bitbang32 bitbang64

.PRECIOUS: $(BUILD)/%.elf $(BUILD32)/%.elf

#all: dirs $(TARGETDUMPS) $(TESTVECTORS) memfile

all:    dirs all64 all32 memfile
all64:  dirs $(TARGETDUMPS) $(TESTVECTORS)
all32:  dirs $(TARGETDUMPS32) $(TESTVECTORS32)

generate:   $(TESTVECTORS)
generate32: $(TESTVECTORS32)

build: debug dirs $(TARGETDUMPS)

#generate: $(TESTVECTORS)

memfile:
	$(MAKE) -f ../riscof/makefile-memfile WORKDIR=$(WALLY)/tests/debug/$(BUILD)
	$(MAKE) -f ../riscof/makefile-memfile WORKDIR=$(WALLY)/tests/debug/$(BUILD32)

debug:
	@echo $(TARGET)
	@echo $(TESTVECTORS)

dirs:
	mkdir -p $(BUILD) $(LOGSDIR) $(TVBUILDDIR) \
	         $(BUILD32) $(LOGSDIR32) $(TVBUILDDIR32)

# --------------------------------------------------------------------
# 64 Bit build
# --------------------------------------------------------------------
$(BUILD)/%.elf.objdump: $(BUILD)/%.elf
	$(OBJDUMP) -D $< > $@

$(BUILD)/%.elf: rv64/%.S
	$(CC) $(ASFLAGS) -o $@ $<

$(TVBUILDDIR)/%.tv: $(BUILD)/%.elf.objdump
	./debugtestgen.py -s $(BUILD)/$(basename $(notdir $@)).elf -t $(TVDIR)/$(basename $(notdir $@)).tcl -i 64
	grep "41b" $(LOGSDIR)/$(basename $(notdir $@)).log | sed 's/.*41b \([^;]*\).*/\1/' > $@
	echo 'w 40000001 @10 -> + 00000000 @00' >> $@

# --------------------------------------------------------------------
# 32 Bit build
# --------------------------------------------------------------------
$(BUILD32)/%.elf.objdump: $(BUILD32)/%.elf
	$(OBJDUMP) -D $< > $@     # reuse the riscv64 objdump — it handles 32-bit ELFs fine

$(BUILD32)/%.elf: rv32/%.S
	$(CC) $(ASFLAGS32) -o $@ $<

$(TVBUILDDIR32)/%.tv: $(BUILD32)/%.elf.objdump
	./debugtestgen.py -s $(BUILD32)/$(basename $(notdir $@)).elf -t $(TVDIR)/$(basename $(notdir $@)).tcl -i 32
	grep "41b" $(LOGSDIR32)/$(basename $(notdir $@)).log | sed 's/.*41b \([^;]*\).*/\1/' > $@
	echo 'w 40000001 @10 -> + 00000000 @00' >> $@

clean:
	@rm -rf $(BUILD)
	@rm -rf $(BUILD32)

# --------------------------------------------------------------------
# Old utility commands. Still useful for debugging tests.
# --------------------------------------------------------------------
sim32:
	spike --isa=rv32imfdc_zicsr +signature=$(TARGET).signature.output +signature-granularity=8 $(TARGET)

sim64:
	spike --isa=rv64gc_zicsr +signature=$(TARGET).signature.output +signature-granularity=8 $(TARGET)

debug32:
	spike -d --isa=rv32imfdc_zicsr +signature=$(TARGET).signature.output +signature-granularity=8 $(TARGET)

debug64:
	spike -d +signature=$(TARGET).signature.output +signature-granularity=8 $(TARGET)

bitbang32:
	spike --isa=rv32imfdc_zicsr --rbb-port=9824 +signature=$(TARGET).signature.output +signature-granularity=8 $(TARGET)

bitbang64:
	spike --isa=rv64gc_zicsr --rbb-port=9824 +signature=$(TARGET).signature.output +signature-granularity=8 $(TARGET)
