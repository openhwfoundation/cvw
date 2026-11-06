# Benchmarks for the core comparison

These scripts produce the CoreMark results in [docs/comparison.adoc](../../docs/comparison.adoc). Each
core runs on the testbench its [riscv-arch-test](https://github.com/riscv/riscv-arch-test) (ACT)
configuration uses, and the program boots, halts, and prints like an ACT test.

## CoreMark (`coremark/`)

The CoreMark port is [benchmarks/coremark](../coremark), the one CORE-V-Wally's own CoreMark runs use;
`coremark/run_all.sh` builds it for each core with `../coremark/build.sh`.

- `crt.S` boots with the configuration's `RVMODEL_BOOT`, sets the stack from its `link.ld`, clears
  `.bss`, calls CoreMark's `main`, and halts with `RVMODEL_HALT_PASS`. `ee_printf` prints through
  `RVMODEL_IO_WRITE_STR`. Core-specific boot steps are behind flags:
  - `-DCLEAR_MCOUNTINHIBIT` clears `mcountinhibit` (CV32E40P, CV32E40X and CV32E40S reset with the
    counters stopped).
  - `-DIBEX_ICACHE` enables Ibex's instruction cache, which resets disabled.
  - `-DVEER_STACK_TOP=<addr>` puts the stack, which holds CoreMark's data, in the VeeR DCCM, as
    VeeR's own CoreMark does.
  - `-DCV32E40S_NO_DATAINDTIMING` clears CV32E40S `cpuctrl.dataindtiming` (not used for the table).
- `core_portme.c` and `core_portme.h` are CoreMark's barebones port. Time is `mcycle` at one tick
  per "second", so CoreMark's 10-second minimum is always met, and CoreMark/MHz =
  Iterations × 10^6 / Total ticks. `-DUSE_RDCYCLE` reads `rdcycle` (PicoRV32), and
  `-DMTIME_ADDR=<addr>` reads a memory-mapped cycle counter (SERV's `servant_timer` at
  0xC000_0000). `-DCOUNT_INSTRET` also prints the retired instructions in the timed region, and
  `-DWALLY_HPM` (used by `benchmarks/coremark/Makefile`) also prints CORE-V-Wally's performance counters.
- `ee_u32` is `signed int` on RV64 and `unsigned int` on RV32, as in CORE-V-Wally's and SiFive's RV64
  ports: the signed type avoids zero extensions after 32-bit operations on RV64. With `unsigned int`,
  RV64 cores execute about 18% more instructions.
- `build.sh <name> <act-config-dir> <march> <mabi> <iterations> [cflags]` builds with
  riscv64-unknown-elf-gcc 15.2.0 and CORE-V-Wally's CoreMark flags:
  `-O3 -finline-functions -finline-limit=400 -falign-jumps=4 -fno-delete-null-pointer-checks
  -fno-rename-registers --param=loop-max-datarefs-for-datadeps=0 -funroll-all-loops
  --param=uninlined-function-insns=8 -fno-tree-vrp -fipa-pta -falign-functions=16 -mbranch-cost=1
  -mtune=sifive-3-series -fno-tree-loop-distribute-patterns -fno-common -mstrict-align`, plus
  `-fwrapv` on RV32. `-march` is each core's subset of IMAFDC, Zba, Zbb, Zbs, and Zbc; other
  extensions (Zcb, Zicond, Zk*, V) are not used.
- `run_all.sh [name ...]` builds and runs every core in its table and `summarize.sh` prints
  CoreMark/MHz. A run counts only if CoreMark prints "Correct operation validated".

`run_all.sh` needs two directories:

- `ACT_CONFIGS`: one directory per configuration, named as in the table, holding the files of the
  ACT configuration (`config/cores/<core>/<config>/` in riscv-arch-test, with symbolic links resolved;
  some come from open riscv-arch-test pull requests, listed in docs/comparison.adoc).
- `CI_TOOLS`: the core installs made by ACT's `.github/scripts/install-<core>.sh`, as
  `$CI_TOOLS/<core>` with an `$CI_TOOLS/<core>.env` that puts its run script on `PATH`, plus:
  - `cv32e40x-dv-nostall`: a copy of the cv32e40x-dv install with the fixed Verilator data-bus stalls
    (two cycles of grant and two of rvalid delay) removed from `tb/core/mm_ram.sv`, so that the core
    runs with zero-wait memory like the others.
  - `cv32e40s-nostall`: the CV32E40S testbenches as `install-cve4.sh` builds them (riscv-arch-test
    #3166, in cv32e40x-dv's core testbench), compiled with the `mm_ram.sv` of `cv32e40x-dv-nostall`,
    as `cv32e40s-nostall/<config>/Vtb_top`.
  - `cva6-snapshot-longrun`: a `CVA6_SNAPSHOT` directory whose `Variane_testharness` wrappers pass
    `+time_out=200000000`, because the testharness stops at 2,000,000 cycles by default.
  - `c910-padfix/run-c910.sh`: a copy of `run-c910.sh` that pads the program image to a whole word
    (`truncate -s %4`) before converting it to `mem.pat`, so that a short last word is not dropped.
  - `xiangshan.env`: puts `run-xiangshan.sh` on `PATH` and sets `XIANGSHAN_EMU` to the emulator built by
    `install-xiangshan.sh` (`KunminghuV2Config`). XiangShan is not in riscv-arch-test's CI.

The run commands and limits for each core are in the table at the top of `run_all.sh`.

## Embench (`embench/`)

- Each Embench benchmark is built with `build.sh <name> <act-config-dir> <march> <mabi> <benchmark> [cflags]`
  with the flags of CORE-V-Wally's Embench speed build (cvw #2031): `-O3 -flto -funroll-loops`, plus `-fwrapv`
  on RV32, `-fdata-sections -ffunction-sections -Wl,-gc-sections`, and newlib's libm and libc. It links
  `benchmarks/coremark/crt.S` (with `-DNO_MEMFUNCS`, so newlib's `memcpy` and `memset` are used) and this directory's
  `main.c`, a copy of Embench's that also prints whether the benchmark's own check passed.
- `-march` has no F or D on any core, because with them GCC removes much of the timed work in nbody, st, and
  minver; the floating-point benchmarks therefore use software floating point.
- RV32 builds use riscv64-unknown-elf-gcc 15.2.0. RV64 builds use a toolchain whose newlib is built with
  `-mcmodel=medany` (GCC 16.1.0; set `RV64_TOOLCHAIN`), because these cores' RAM starts at 0x8000_0000, beyond
  the reach of the default medlow newlib. Sargantana, which has no C, is built for RV64IM (the medany toolchain has
  no non-compressed RV64IMA library; Embench does not use atomics).
- `boardsupport.c` reads `mcycle` (or `rdcycle` with `-DUSE_RDCYCLE`, or the counter at `-DMTIME_ADDR`) in
  `start_trigger` and `stop_trigger` and prints the cycles. `score.sh` computes the score as Embench's
  `benchmark_speed.py` does at 1 MHz: the geometric mean over the 22 benchmarks of baseline time / (cycles / 1000).
- `run_all.sh` uses `ACT_CONFIGS` and `CI_TOOLS` as above. In `CI_TOOLS` it also expects simulators rebuilt with
  higher cycle limits, because some Embench benchmarks run longer than the ACT builds allow:
  `veer-eh1-longrun` and `veer-el2-longrun` (VeeR built as ACT's install scripts do, plus `-GMAX_CYCLES=2000000000`),
  and `e902-longrun` (`+define+MAX_RUN_TIME=20000000000`).
