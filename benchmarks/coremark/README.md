# CoreMark

This is the CoreMark port used both for CORE-V-Wally and for the other cores in
[docs/comparison.adoc](../../docs/comparison.adoc). It boots, halts, and prints with a configuration's
riscv-arch-test `rvmodel_macros.h` and links with its `link.ld`, so the same program runs on CORE-V-Wally's
testbench and on each other core's ACT testbench. [benchmarks/comparison/README.md](../comparison/README.md)
describes the port and its options.

`make run` builds CoreMark for `CONFIG` (default `rv$(XLEN)gc`) and `ARCH` with `config/$(CONFIG)/act` and
runs it on `wsim` with Verilator. `-DWALLY_HPM` adds the score, CPI, and CORE-V-Wally's performance counters
over the timed region. `coremark_sweep.py` runs it for each architecture in its list and writes
`coremark_results.csv`, which `regression-wally --benchmark` compares with `expected_coremark_results.csv`.

```bash
make run XLEN=64 ARCH=rv64gc_zba_zbb_zbc_zbs
```
