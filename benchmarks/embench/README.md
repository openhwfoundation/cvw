# Wally Embench builds

`make build_speedopt_speed build_speedopt_size` builds the speed-optimized
executables and their separate code-size measurement. Run `make clean` before
changing optimization flags or `ARCH`: the upstream builder caches objects by
source timestamp rather than by compiler command.

The speed targets use `-O3 -flto -funroll-loops`, with `-fwrapv` for RV32.
RV32 needs wrapping signed arithmetic for Embench's random-number generator;
plain `-O3 -flto` fails the `crc32` result check with GCC 15.2.0.
The size-optimized targets continue to use `-Os`.

The Makefile uses the RV32 Wally board and defaults to `ARCH=rv32imac_zicsr`.
For the bit-manipulation extensions implemented by `rv32gc`, use
`ARCH=rv32imac_zicsr_zba_zbb_zbc_zbs`.

## Speed-opt size measurement

`build_speedopt_size` retains the existing `-msave-restore` setting and links
Embench's dummy libraries, measuring executable text rather than the complete
application with real libraries. `size-gcc.py` compiles the four dummy support
files with `-fno-lto` while keeping LTO enabled for benchmark and ordinary
support code. This prevents optimization through fake library bodies and keeps
helpers that GCC introduces during final code generation. The wrapper uses
`EMBENCH_CC`, which defaults to `riscv64-unknown-elf-gcc`.

With GCC 15.2.0 and Embench revision
`54fd9a0f10aabc662991567ca19ff3e61bfd3939`, all 22 default-target benchmarks
pass on the same Verilator `rv32gc` model before and after the change:

| Default RV32 target | Previous `-O2` | New speed options | Change |
|---|---:|---:|---:|
| Speed/MHz, geometric mean | 1.1862 | 1.6348 | +37.81% |
| Speed-opt size, geometric mean | 1.16 | 2.02 | +73.47% |
| Sum of executable text in size builds | 72,028 bytes | 129,618 bytes | +79.96% |

Larger size scores mean larger code. Percent changes use unrounded measurements.
The checked-in expected speed-opt results come from this default configuration.
They include all 22 programs in the pinned revision.

These size results differ from measuring the real speed executables' text plus
data: optimization can remove library dependencies while enlarging benchmark
code. Do not use that whole-application footprint as Embench's size score.
