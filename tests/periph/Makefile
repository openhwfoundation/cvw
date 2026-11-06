# Makefile to build the self-checking peripheral tests
#
# Each test embeds its expected signature (see expected_signature at the end of each .S file) and
# checks every signature entry as it is written, so no reference file or signature diff is needed.
# Everything the tests need is in this directory: WALLY-env.h (register-width macros, halt, and
# signature area), WALLY-TEST-LIB.h (trap handler and test-table interpreter), WALLY-uart.h (UART
# register map and helper routines for the WALLY-uart-* tests), and link.ld.
#
# Each source in src/ is built for both RV32 and RV64 into rv32/ and rv64/.  WALLY-periph-01 is also
# built with -DM_MODE_ONLY (as WALLY-periph-m-01) for RV32 configurations without supervisor mode.

# Disable builtin rules because they are a shorter (but incorrect) path that Make will use by default
MAKEFLAGS += --no-builtin-rules
NAMES     := $(notdir $(basename $(sort $(wildcard src/*.S))))
ELFS      := $(addprefix rv32/,$(addsuffix .elf,$(NAMES))) $(addprefix rv64/,$(addsuffix .elf,$(NAMES))) rv32/WALLY-periph-m-01.elf
OBJDUMPS  := $(addsuffix .objdump, $(ELFS))
MEMFILES  := $(addsuffix .memfile, $(ELFS))
HEADERS   := $(wildcard *.h) link.ld
CFLAGS    := -static -mcmodel=medany -nostdlib -nostartfiles -g -T link.ld -Wl,--no-warn-rwx-segments -I .
# make SELFCHECK_ALL=1 reports every mismatching signature entry on the console instead of halting at
# the first one (see WALLY-TEST-LIB.h).  Rebuild with make clean when switching.
ifeq ($(SELFCHECK_ALL),1)
CFLAGS    += -DSELFCHECK_ALL
endif

all: $(ELFS) $(OBJDUMPS) $(MEMFILES)

# Create disassembly
%.elf.objdump: %.elf
	riscv64-unknown-elf-objdump -S -D $< > $@

# Create memfile
%.elf.memfile: %.elf
	elf2hex $< $@

.PRECIOUS: $(ELFS)
rv32/%.elf: src/%.S $(HEADERS) | rv32
	riscv64-unknown-elf-gcc -march=rv32i_zicsr_zifencei -mabi=ilp32 $(CFLAGS) -o $@ $<

rv64/%.elf: src/%.S $(HEADERS) | rv64
	riscv64-unknown-elf-gcc -march=rv64i_zicsr_zifencei -mabi=lp64 $(CFLAGS) -o $@ $<

rv32/WALLY-periph-m-01.elf: src/WALLY-periph-01.S $(HEADERS) | rv32
	riscv64-unknown-elf-gcc -march=rv32i_zicsr_zifencei -mabi=ilp32 -DM_MODE_ONLY $(CFLAGS) -o $@ $<

rv32 rv64:
	mkdir -p $@

clean:
	rm -rf rv32 rv64

.PHONY: all clean
