# coremark/Makefile
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26

XLEN       ?=
ARCH       ?=
ABI        ?= $(if $(findstring 64,$(XLEN)),lp64,ilp32)

TOOLPREFIX ?= riscv64-unknown-elf-

LINKER     ?=

WORK_DIR   ?= $(CURDIR)/work

WALLY_PORT_DIR := $(WALLY)/benchmarks/coremark/riscv64-baremetal
cmbase         := $(WALLY)/addins/coremark

PORT_CFLAGS ?= \
    -g \
    -mabi=$(ABI) \
    -march=$(ARCH) \
    -static \
    -falign-functions=16 \
    -mbranch-cost=1 \
    -DSKIP_DEFAULT_MEMSET \
    -mtune=sifive-3-series \
    -O3 \
    -finline-functions \
    -falign-jumps=4 \
    -fno-delete-null-pointer-checks \
    -fno-rename-registers \
    --param=loop-max-datarefs-for-datadeps=0 \
    -funroll-all-loops \
    --param=uninlined-function-insns=8 \
    -fno-tree-vrp \
    -fwrapv \
    -fipa-pta \
    -nostdlib \
    -nostartfiles \
    -ffreestanding \
    -mstrict-align \
    -DTOTAL_DATA_SIZE=2000 \
    -DMAIN_HAS_NOARGC=1 \
    -DPERFORMANCE_RUN=1 \
    -DITERATIONS=10 \
    -DXLEN=$(XLEN)

cmscript_files := \
  $(cmbase)/core_main.c $(cmbase)/core_list_join.c $(cmbase)/coremark.h \
  $(cmbase)/core_matrix.c $(cmbase)/core_state.c $(cmbase)/core_util.c

cmconfig_files := \
  $(WALLY_PORT_DIR)/core_portme.h $(CURDIR)/core_portme.c $(WALLY_PORT_DIR)/core_portme.mak \
  $(CURDIR)/crt.S $(WALLY_PORT_DIR)/encoding.h $(CURDIR)/util.h $(CURDIR)/syscalls.c \
  $(LINKER)

CC := $(TOOLPREFIX)gcc

# Flags from upstream core_portme.mak (previously added silently by the upstream Makefile)
CFLAGS := $(PORT_CFLAGS) \
    -mcmodel=medany \
    -fno-tree-loop-distribute-patterns \
    -fno-common \
    -I$(cmbase) -I$(WALLY_PORT_DIR) \
    -T $(LINKER) \
    -DFLAGS_STR='"$(PORT_CFLAGS)"'
LFLAGS := -static-libgcc -lgcc -lm -lgcc

# ---- Source files ----
CM_SRCS := \
    $(cmbase)/core_main.c $(cmbase)/core_list_join.c \
    $(cmbase)/core_matrix.c $(cmbase)/core_state.c $(cmbase)/core_util.c

PORT_SRCS := $(CURDIR)/core_portme.c $(CURDIR)/syscalls.c $(CURDIR)/crt.S

SRCS    := $(CM_SRCS) $(PORT_SRCS)
HEADERS := $(cmbase)/coremark.h $(WALLY_PORT_DIR)/core_portme.h \
           $(WALLY_PORT_DIR)/encoding.h $(CURDIR)/util.h

.PHONY: all clean

all: $(WORK_DIR)/coremark.bare.riscv.elf

$(WORK_DIR)/coremark.bare.riscv.elf: $(SRCS) $(HEADERS) $(LINKER) Makefile
	@mkdir -p $(WORK_DIR)
	$(CC) $(CFLAGS) $(SRCS) -o $@ $(LFLAGS)

clean:
	rm -rf $(WORK_DIR)
