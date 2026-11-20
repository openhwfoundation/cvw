# Makefile for the directed superscalar tests
#
# Each .S here is a self-contained RV32 test: it carries its own entry point, trap handler and tohost,
# and reports through tohost (1 = pass, (index << 1) | 1 = the check that failed).  RV32 is needed
# because only the RV32 configurations divide on the MDU; rv64gc divides on the FPU (IDIV_ON_FPU).
# Run with:  wsim rv32gc tests/superscalar --sim verilator

# Disable builtin rules because they are a shorter (but incorrect) path that Make will use by default
MAKEFLAGS += --no-builtin-rules
SOURCES   := $(sort $(wildcard *.S))
ELFS      := $(SOURCES:.S=.elf)
OBJDUMPS  := $(addsuffix .objdump, $(ELFS))
MEMFILES  := $(addsuffix .memfile, $(ELFS))

all: $(ELFS) $(OBJDUMPS) $(MEMFILES)

%.elf.objdump: %.elf
	riscv64-unknown-elf-objdump -S -D $< > $@

%.elf.memfile: %.elf
	elf2hex $< $@

.PRECIOUS: %.elf
%.elf: %.S
	riscv64-unknown-elf-gcc -march=rv32imc_zicsr_zifencei -mabi=ilp32 -static -mcmodel=medany -nostdlib -nostartfiles \
	    -g -T ../../examples/link/link.ld -Wl,--no-warn-rwx-segments -o $@ $<

clean:
	rm -f *.elf *.objdump *.memfile *.addr *.lab

.PHONY: all clean
