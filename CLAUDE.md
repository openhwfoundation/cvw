# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

CORE-V-Wally (cvw) is a configurable, 5-stage pipelined RISC-V processor written in SystemVerilog. It supports RV32/RV64 with virtually all standard ISA extensions (A, B, C, D, F, M, Q, Zk*, etc.), virtual memory, PMP, and standard RISC-V peripherals. It passes the RISC-V Arch Tests and boots Linux.

## Environment Setup

Before doing anything, source the setup script (required every session):
```bash
source setup.sh
```

This sets `$WALLY` (repo root) and `$RISCV` (toolchain installation at `~/riscv` or `/opt/riscv`), activates the Python virtual environment, and adds `$WALLY/bin` to `$PATH`.

## Build and Test Commands

### Build all test vectors (run once after cloning or pulling)
```bash
cd $WALLY && make --jobs
```
This builds: riscv-arch-test suites, floating point vectors, ZSBL, coverage tests, and branch predictor simulator.

### Run a simulation
```bash
wsim <config> <elf_or_directory>... [options]
```

Every ELF named, and every `*.elf` found (recursively) under every directory named, runs back-to-back in one simulation session. All tests are self-checking; the simulation ends with `SUCCESS! All tests ran without failures.` or `FAIL: N test programs had errors`.

Common examples:
```bash
ACT=$WALLY/addins/riscv-arch-test/work/cvw-rv64gc/elfs
wsim rv64gc $ACT/rv64i/I --sim verilator        # run a whole ACT directory in one session
wsim rv64gc $ACT/rv64i/I/I-add-01.elf --gui     # one ELF, Questa with waveform GUI
wsim rv32gc a.elf b.elf c.elf --sim verilator   # an explicit group of ELFs
wsim rv64gc test.elf --sim verilator --vcd      # Generate VCD waveform
wsim rv64gc test.elf --lockstep                 # Lock-step vs ImperasDV (Questa/VCS only; one ELF at a time)
wsim rv64gc $ACT/priv/Sv --fcov                 # Functional coverage (Questa only)
wsim rv64gc buildroot                           # Linux boot from prebuilt memory images
wsim rv32gc bench.elf --test coremark           # ELF run with a special testbench mode (coremark, embench)
```

Key options: `--sim {questa,verilator,vcs}`, `--gui`, `--ccov` (code coverage), `--fcov` (functional coverage), `--lockstep`/`--lockstepverbose`, `--vcd`, `--args`, `--params`, `--define`, `--name` (log/coverage file name), `--test` (special mode: buildroot, fpga, coremark, embench).

### Run full regression
```bash
regression-wally                        # rv32imc, rv32gc, rv64gc ACT + periph tests, Verilator by default
regression-wally --nightly              # extended nightly suite
```
`regression-wally` first builds the ACT ELFs it needs (`make -C addins/riscv-arch-test CONFIG_FILES=...`, incremental) and the periph/coverage tests, then runs each leaf directory of ACT ELFs as one `wsim` session, in parallel across directories. Compiled designs in `sim/<sim>/wkdir` are kept between regressions and recompiled only when a source file is newer. Set `ACTDIR` to use a different riscv-arch-test checkout.

### Run code coverage
```bash
regression-wally --ccov             # look at results in rv64gc_uncovered_hierarchical.rpt
```
Also possible to run individual files and merge them into the overall coverage.

### Lint
```bash
lint-wally                              # lint standard configs with Verilator
lint-wally --nightly                    # lint all derivative configs too
```

### Generate derivative configurations
```bash
derivgen.pl                             # regenerates config/deriv/ from config/derivlist.txt
```

## Architecture

### Directory Structure
- `src/` — RTL source (SystemVerilog)
- `config/` — Configuration files per target (`rv64gc`, `rv32gc`, `rv32i`, etc.)
- `testbench/` — Top-level testbenches (`testbench.sv`, `testbench_fp.sv`)
- `sim/` — Simulation infrastructure (`questa/`, `verilator/`, `vcs/`)
- `tests/` — Test suites (`coverage/`, `fp/`, `custom/`, `periph/` self-checking peripheral tests)
- `addins/` — Git submodules (riscv-arch-test, sail-riscv, riscv-dv, embench, etc.)
- `bin/` — Scripts (`wsim`, `regression-wally`, `lint-wally`, `derivgen.pl`, etc.)
- `fpga/` — FPGA-specific files
- `linux/` — Linux boot support

### RTL Hierarchy

```
wallypipelinedsoc (src/wally/wallypipelinedsoc.sv)
├── wallypipelinedcore (src/wally/wallypipelinedcore.sv)
│   ├── ifu (src/ifu/ifu.sv)          — Instruction Fetch Unit: PC, icache, branch predictor
│   │   └── bpred/                    — Branch predictors (BTB, GSHARE, RAS, etc.)
│   ├── ieu (src/ieu/ieu.sv)          — Integer Execution Unit: ALU, control, datapath, regfile
│   ├── lsu (src/lsu/lsu.sv)          — Load/Store Unit: dcache, HPTW, atomics, endian swap
│   ├── fpu (src/fpu/)                — Floating Point Unit (F, D, Q, ZFH)
│   ├── privileged (src/privileged/)  — CSRs, traps, privilege modes, PMP
│   ├── hazard (src/hazard/)          — Pipeline stall/flush control
│   ├── mdu (src/mdu/)                — Multiply/Divide Unit
│   └── ebu (src/ebu/)                — External Bus Unit (AHB arbiter)
├── uncore (src/uncore/)              — Peripherals: RAM, ROM, CLINT, PLIC, UART, GPIO, SPI
├── cache (src/cache/)                — Shared cache infrastructure (used by IFU and LSU)
└── mmu (src/mmu/)                    — MMU: TLBs, page table walker, PMP/PMA checkers
```

### Configuration System

Each configuration target (e.g., `rv64gc`) has a directory under `config/` containing `config.vh`. These `localparam` settings are loaded once at elaboration time into the `cvw_t` struct (defined in `src/cvw.sv`), which is passed as a parameter `#(parameter cvw_t P)` to every module. This avoids global `define` conflicts.

Shared derived parameters (virtual memory constants, floating-point widths, mode encodings) live in `config/shared/config-shared.vh`.

Derivative configurations (variations of base configs for design-space exploration) are generated by `derivgen.pl` from `config/derivlist.txt` into `config/deriv/`.

### ACT test-generation configurations

cvw owns the riscv-arch-test (ACT) configuration for each of its configurations in `config/<cfg>/act/` (`test_config.yaml`, the UDB architecture yaml `cvw-<cfg>.yaml`, `sail.json`, `link.ld`, `rvmodel_macros.h`, `run_cmd.txt`). `make act` and `regression-wally` build tests from these; ACT names its work directory after the yaml's `name:` (e.g. `work/cvw-rv64gc/`). The ACT repository keeps copies of the standard ones in `addins/riscv-arch-test/config/cores/cvw/` for its own CI. `bin/actconfig-sync --check` (run by `lint-wally`) verifies that each UDB yaml's extension list agrees with the `*_SUPPORTED` parameters in `config.vh` (a parameter absent from `config.vh` counts as 0), and warns where ACT's copies differ — that warning is not fatal, because only a commit in the ACT repository can clear it; `actconfig-sync --push` copies cvw's versions into the ACT tree to commit there. When adding an extension parameter to `config.vh`, add its UDB name to `PARAM_TO_EXTENSION` in `bin/actconfig-sync`.

### Pipeline Stages

Five stages: Fetch (F), Decode (D), Execute (E), Memory (M), Writeback (W). Stall and flush signals (`StallF`/`FlushD` etc.) are computed in `hazard.sv` and threaded through every stage register.

### Simulators

- **Verilator**: Default for regression; open-source; no license needed. Compiled per config in `sim/verilator/wkdir/`.
- **Questa** (Siemens): Required for code/functional coverage, lockstep, testbench_fp, and GUI waveforms. Uses `sim/questa/wkdir/`.
- **VCS** (Synopsys): Supports standard tests and lockstep.

Lockstep mode runs Wally in lock-step against ImperasDV (commercial) or the RISC-V Sail model for instruction-by-instruction comparison.

### Test Infrastructure

There is no central test list; tests are ELF files passed to `wsim` by path or directory:
- `addins/riscv-arch-test/work/cvw-<config>/elfs/` — RISC-V Arch Tests (ACT4), built per cvw configuration by `make act` (or by `regression-wally`); one leaf directory per extension/feature
- `tests/periph/rv32/`, `tests/periph/rv64/` — Self-checking peripheral tests: one source per test in `tests/periph/src/`, built for both widths by `make periph`; each embeds its expected signature and compares every entry as it is written
- `tests/coverage/` — Coverage-targeted tests for each unit; they pass if they run to completion

Every test reports its result by storing to `tohost`: 1 = pass, `(exit code << 1) | 1` = fail. A test that halts without storing to `tohost` is reported as a failure.
- `buildroot` — Linux boot from prebuilt memory images (`wsim buildroot buildroot`)

`wsim` generates each ELF's `.memfile` (in parallel, via `testbench/Makefile`), looks up its `tohost` and `begin_signature` addresses with `riscv64-unknown-elf-nm`, writes the list (`path tohost begin_signature` per line) to `sim/<sim>/testlists/`, and passes it as `+ElfList=`. The testbench runs each ELF in turn, captures the value stored to `tohost`, and prints a single summary at the end. `.objdump.addr`/`.objdump.lab` label maps (`bin/extractFunctionRadix.sh`) are only built when the `functionName` debug tracer is enabled (`--gui`, `PrintHPMCounters`, `BPRED_LOGGER`).

The ACT submodule is `addins/riscv-arch-test` (upstream `act4` branch). To work on a fork, add it as a remote inside the submodule and check out its branch; keep the committed pointer on an upstream commit.
