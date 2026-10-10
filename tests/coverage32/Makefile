# RV32 self-checking coverage tests.  Kept out of tests/coverage, whose ELFs the nightly
# regression runs on rv64gc in lockstep.
MAKEFLAGS += --no-builtin-rules
SOURCES  ?= $(sort $(wildcard *.S))
ELFS     := $(SOURCES:.S=.elf)

all: $(addsuffix .objdump, $(ELFS)) $(addsuffix .memfile, $(ELFS))

%.elf.objdump: %.elf
	riscv64-unknown-elf-objdump -S -D $< > $@

%.elf.memfile: %.elf
	elf2hex $< $@

.PRECIOUS: %.elf
%.elf: %.o
	riscv64-unknown-elf-gcc -g -o $@ -march=rv32gc -mabi=ilp32 -mcmodel=medany -nostartfiles -T../../examples/link/link.ld $<

%.o: %.s
	riscv64-unknown-elf-as -g -o $@ -march=rv32gc -mabi=ilp32 $<

%.s: %.S
	riscv64-unknown-elf-gcc -E -g -o $@ $<

clean:
	rm -f *.elf *.elf.objdump *.elf.memfile *.o *.s
