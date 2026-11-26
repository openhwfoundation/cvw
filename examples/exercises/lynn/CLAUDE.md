# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this directory.

## Project Overview

This is a **competitive RISC-V processor design exercise** within the CORE-V Wally (CVW) repository. Students implement their own RISC-V processor in SystemVerilog, validate it against the RISC-V architecture tests, benchmark it with CoreMark, synthesize it with Synopsys Design Compiler, and compete for the highest score.

**Scoring formula** (`bin/score.py`): `Score = 10^30 / ((MTIME × Critical_Path_ns)^3 × Area_um2)`, where MTIME is the CoreMark run time in cycles. **Higher is better.** Cubing the execution time rewards fast designs heavily; area is penalized linearly.

## Environment Setup

```bash
# Required every session: sets $WALLY and $RISCV and adds the tools to $PATH
source ~/cvw/setup.sh
```

## Common Commands

```bash
make lint            # Lint the processor RTL and testbench with Verilator
make build           # Compile the RTL and testbench for Questa
make bringup_test    # Run the small bringup assembly tests (tests/bringup)
make C_test          # Run the C test (tests/C/HelloWorld.c)
make test            # Generate and run the RISC-V architecture tests (ACT4) for PROCESSOR_CONFIG
make coremark        # Run CoreMark
make synth           # Synthesize with Design Compiler through $WALLY/synthDC
make score           # Compute the score (needs synth and coremark results); writes score.log
make bug             # Bug lab: run the bug_scripts against the sample processor

make run ELFS="path/to/test.elf"           # Run specific ELF files
make run ELFS="path/to/test.elf" GUI=1     # ... in the Questa GUI
make run ELFS="path/to/test.elf" SAIL=1    # ... on the Sail reference model instead of the processor

make clean           # Remove build artifacts and score.log
make clean-act4      # Remove architecture test artifacts
make clean-coremark  # Remove CoreMark artifacts
make clean-synth     # Remove synthesis artifacts
make clean-all       # All of the above
```

## Key Makefile Configuration Variables

All are overridable on the command line (e.g., `make build XLEN=64`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `XLEN` | `32` | Data width (32 or 64) |
| `PROCESSOR_DIR` | `sample_processor/src` | Directory containing all processor RTL (every `.sv`/`.svh` is compiled) |
| `INC_DIR` | `sample_processor/incdir/` | Include directory (parameters) |
| `PROCESSOR_TOP` | `riscvsingle` | Top-level module name of the processor |
| `PROCESSOR_CONFIG` | `sample_processor/config` | Linker script, Sail configuration, and ACT test configuration |
| `ARCH` | `rv$(XLEN)i_zicsr` | ISA string for compiling tests and CoreMark |
| `SYNTH_TECH` | `sky130` | Synthesis technology (`sky130`, `tsmc28`, or `tsmc28psyn`) |
| `SYNTH_TOP` | `$(PROCESSOR_TOP)` | Module to synthesize; set it to a submodule to find that module's critical path |

## Architecture

### Processor Interface Contract

The testbench (`tb/testbench.sv`) instantiates `PROCESSOR_TOP` with this port list (from `sample_processor/src/riscvsingle.sv`):

```systemverilog
module <PROCESSOR_TOP> (
    input  logic              clk,
    input  logic              reset,
    output logic [XLEN-1:0]   PC,           // instruction fetch address
    input  logic [31:0]       Instr,        // fetched instruction
    output logic [XLEN-1:0]   IEUAdr,       // data memory address
    input  logic [XLEN-1:0]   ReadData,     // data memory read data
    output logic [XLEN-1:0]   WriteData,    // data memory write data
    output logic              MemEn,        // data memory enable
    output logic              WriteEn,      // data memory write enable
    output logic [XLEN/8-1:0] WriteByteEn   // byte lane enables
);
```

### Testbench (`tb/`)

- **`testbench.sv`**: instantiates separate instruction and data memories (`ram1p1rwb`) and the processor, and implements the HTIF `tohost` protocol (test pass/fail and console output). Memories are loaded from the `.memfile` that `elf2hex` makes from each ELF.
- **`ram1p1rwb.sv`**: parameterized single-port RAM with byte-enable writes.
- **`waves.do`**: the waveform setup Questa loads (`WAVES_DO`) when it exists.
- Both memories start at `0x8000_0000`. The MTIME counter is at `0x0200_bff8`.
- `tohost`: writing `1` signals a pass, any other odd value `(code << 1) | 1` a failure, and `0x01010000_000000xx` prints the character `xx`.

### Test Flows

1. **Bringup** (`tests/bringup/`): minimal assembly tests for individual instructions (add, sub, and, or, slt, beq).
2. **C test** (`tests/C/`): `HelloWorld.c`, compiled with the RISC-V toolchain.
3. **Architecture tests** (`tests/act4/`): RISC-V Architecture Tests generated from `$WALLY/addins/riscv-arch-test` for the extensions in `PROCESSOR_CONFIG/lynn-rv32I.yaml` (I, Sm, Zicntr, Zicsr, Zihpm). `bin/scan_test_logs.py` summarizes the results.
4. **CoreMark** (`coremark/`): the benchmark whose run time feeds the score.

### Synthesis (`synth/`)

`synth/Makefile` runs `$WALLY/synthDC` with `LYNN=1`, synthesizing `SYNTH_TOP` from `PROCESSOR_DIR`. Each run goes in its own directory under `synth/work/`.

### Scoring (`bin/score.py`)

Reads `reports/qor.rep` and `reports/timing.rep` from the newest run in `synth/work/` and the CoreMark log `coremark/work/coremark.bare.riscv.elf.sim.log`, and writes `score.log`.

### Processor Implementations

- **`sample_processor/`**: a single-cycle RV32I processor (`riscvsingle`) to start from.

To use your own processor, set `PROCESSOR_DIR`, `INC_DIR`, `PROCESSOR_TOP`, and (if its configuration differs) `PROCESSOR_CONFIG` in the Makefile or on the command line.
