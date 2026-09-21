# Disable builtin rules because they are a shorter (but incorrect) path that Make will use by default
MAKEFLAGS += --no-builtin-rules
SRCDIR    := .
SRCEXT    := S
AEXT      := s
OBJEXT    := o
EXEEXT    := elf
SOURCES		?= $(shell find $(SRCDIR) -type f -regex ".*\.$(SRCEXT)" | sort)
ELFS   		:= $(SOURCES:.$(SRCEXT)=.$(EXEEXT))
OBJDUMPS  := $(addsuffix .objdump, $(ELFS))
MEMFILES  := $(addsuffix .memfile, $(ELFS))

all: $(OBJDUMPS) $(MEMFILES)

# Create disassembly
%.elf.objdump: %.elf
	riscv64-unknown-elf-objdump -S -D $< > $@
	extractFunctionRadix.sh $@

# Create memfile
%.elf.memfile: %.elf
	elf2hex $< $@

# Link object file to create executable
.PRECIOUS: %.$(EXEEXT)
%.$(EXEEXT): %.$(OBJEXT)
	riscv64-unknown-elf-gcc -g -o $@ -mcmodel=medany -nostartfiles -T../../examples/link/link.ld $*.o

# Assemble into object files
%.$(OBJEXT): %.$(AEXT)
	riscv64-unknown-elf-as -g -o $@ -march=rv64gqc_zcb_zfa_zba_zbb_zbc_zbs_zfh_zicboz_zicbop_zicbom_zbkb_zbkx_zknd_zkne_zknh_svinval -mabi=lp64 $<

# Preprocess assembly files
%.$(AEXT): %.$(SRCEXT) WALLY-init-lib.h
	riscv64-unknown-elf-gcc -E -g -o $@ $<

sim: %.$(EXEEXT)
	spike +signature=%.signature.output +signature-granularity=8 %.elf
	diff --ignore-case %.signature.output %.reference_output || exit
	echo "Signature matches! Success!"

clean:
	rm -f *.elf *.objdump *.signature.output *.addr *.lab *.memfile *.o *.s
