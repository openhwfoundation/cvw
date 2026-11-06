#!/bin/bash
# Build CoreMark for a riscv-arch-test configuration.
# usage: build.sh <name> <act-config-dir> <march> <mabi> <iterations> [extra cflags]
# <act-config-dir> holds the configuration's link.ld and rvmodel_macros.h.
# The compiler flags are CORE-V-Wally's, for every core.  OUT sets the output directory.
set -e
name=$1 cfg=$2 march=$3 mabi=$4 iters=$5; shift 5
P=$(cd "$(dirname "$0")" && pwd)
C=${COREMARK:-$WALLY/addins/coremark}
OUT=${OUT:-$P/build/$name-$iters}; mkdir -p $OUT
wrap=""; [[ $march == rv32* ]] && wrap="-fwrapv"
FLAGS="-O3 -finline-functions -finline-limit=400 -falign-jumps=4 -fno-delete-null-pointer-checks -fno-rename-registers \
--param=loop-max-datarefs-for-datadeps=0 -funroll-all-loops --param=uninlined-function-insns=8 -fno-tree-vrp $wrap -fipa-pta \
-falign-functions=16 -mbranch-cost=1 -mtune=sifive-3-series -fno-tree-loop-distribute-patterns -fno-common -mstrict-align"
riscv64-unknown-elf-gcc -march=$march -mabi=$mabi -mcmodel=medany -static -nostdlib -nostartfiles -ffreestanding \
  $FLAGS -DPERFORMANCE_RUN=1 -DITERATIONS=$iters -DTOTAL_DATA_SIZE=2000 -DMAIN_HAS_NOARGC=1 \
  -DFLAGS_STR="\"$FLAGS\"" "$@" -I$P -I$C -I$cfg -T $cfg/link.ld \
  $P/crt.S $C/core_list_join.c $C/core_main.c $C/core_matrix.c $C/core_state.c $C/core_util.c \
  $P/core_portme.c $P/ee_printf.c -lgcc -o $OUT/coremark.elf
echo $OUT/coremark.elf
