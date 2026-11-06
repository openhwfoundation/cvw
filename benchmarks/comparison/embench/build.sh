#!/bin/bash
# Build one Embench benchmark for a riscv-arch-test configuration.
# usage: build.sh <name> <act-config-dir> <march> <mabi> <benchmark> [extra cflags]
# Flags are those of CORE-V-Wally's Embench speed build (cvw #2031): -O3 -flto -funroll-loops, -fwrapv on RV32.
# RV64 needs a medany newlib (RAM is at 0x8000_0000 on these cores); set RV64_TOOLCHAIN to its bin directory.
set -e
name=$1 cfg=$2 march=$3 mabi=$4 bench=$5; shift 5
P=$(cd "$(dirname "$0")" && pwd)
E=${EMBENCH:-$WALLY/addins/embench-iot}
CRT=$P/../../coremark/crt.S
CC=riscv64-unknown-elf-gcc
[[ $march == rv64* ]] && CC=${RV64_TOOLCHAIN:?set to the bin directory of a medany riscv64-unknown-elf toolchain}/riscv64-unknown-elf-gcc
OUT=$P/build/$name/$bench; mkdir -p $OUT
wrap=""; [[ $march == rv32* ]] && wrap="-fwrapv"
$CC -march=$march -mabi=$mabi -mcmodel=medany -O3 -flto -funroll-loops $wrap -std=gnu17 \
  -fdata-sections -ffunction-sections -Wl,-gc-sections -nostartfiles -static -DNO_MEMFUNCS -DHAVE_CONFIG_H "$@" \
  -I$P -I$E/support -I$E/config/riscv32/chips/generic -I$cfg -T $cfg/link.ld \
  $CRT $E/src/$bench/*.c $P/main.c $E/support/beebsc.c $E/config/riscv32/chips/generic/chipsupport.c \
  $P/boardsupport.c $P/syscalls.c -lm -lc -lgcc -o $OUT/$bench.elf
echo $OUT/$bench.elf
