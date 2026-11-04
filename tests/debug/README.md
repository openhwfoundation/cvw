# Debug tests

Each test has two parts:
- an assembly program (`rv64/<test>.S`, `rv32/<test>.S`) that the hart runs;
- an OpenOCD Tcl script (`testvectors/<test>.tcl`) that plays the debugger.

Spike provides the expected results. The script runs against Spike, and the JTAG/DMI traffic is recorded as a testvector file. The testbench's debugger (`testbench/common/debugger.sv`) then replays that file against Wally and compares the responses.

## Generating testvectors on Spike

```bash
source $WALLY/setup.sh
cd $WALLY/tests/debug
make all64 all32                     # every test
make build/testvectors/<test>.tv     # one rv64 test (build32/ for rv32)
```

For each test, `debugtestgen.py`:
1. starts Spike on the test's ELF, with a DM configured like Wally's:
   `--dm-progsize=0 --dm-no-hasel --dm-no-halt-groups --dm-no-impebreak --dm-datacount=2`;
2. runs OpenOCD with the test's Tcl script on Spike's remote-bitbang port.

`tv_from_log.py` then turns OpenOCD's log (`build/log/<test>.log`) into `build/testvectors/<test>.tv`.

To watch a single test on Spike (for example, while writing a script), run:

```bash
./debugtestgen.py -s build/<test>.elf -t testvectors/<test>.tcl -i 64
```

Then read `build/log/<test>.log`.

`make -j` works. `WALLY-debug-catch-replay` is timing-sensitive, though, and can hang under load. A run that takes longer than 10 minutes fails instead of hanging. Serial generation of every test takes under a minute.

## Running on Wally

```bash
tests/debug/run_rule_tests.sh [-s questa|verilator] [-x 64|32] 'WALLY-debug-*'
```

For each test, this regenerates the vectors, builds the memfile, and runs `wsim`. It prints one line per test: PASS, FAIL, GENFAIL (vector generation failed), HANG or ERROR. Logs are written to `build*/rulelogs/`. A single test can also be run directly:

```bash
wsim debug64 tests/debug/build/<test>.elf --debug tests/debug/build/testvectors/<test>.tv
```

## Per-rule tests

Tests named `WALLY-debug-<rule>` check one normative rule of the Debug specification each. `<rule>` is the rule name from the Debug normative-rule tags:
- `dm_*`: riscv/riscv-isa-manual#3483 (Debug Module);
- `Sdext_*`: riscv/riscv-isa-manual#3484 (Sdext);
- `dtm_*`: riscv/riscv-isa-manual#3485 (JTAG DTM).

The shared Tcl helpers are in `testvectors/lib/`. `rules.tcl` describes the directives (`tv_rule`, `tv_check`, `poll_until`).

A per-rule test compares only the responses the rule is about. Its testvector file starts with `#pragma strict`, which also turns off the testbench's `knownExceptions` waivers. Raw JTAG scans (`ir`/`dr`/`tlr` lines, from `lib/dtm.tcl`) test the DTM itself.

### Where Spike differs from the spec

Spike's DM and DTM don't follow the spec everywhere. Where they don't, a test checks the spec value instead of Spike's response, and the testvector file shows the difference on the line above the check:

```
# spec value @10: Spike returned + 80000001
```

To list every such case after generating the vectors:

```bash
grep -h "# spec value" build*/testvectors/*.tv | sort | uniq -c
```

These differences are filed as riscv-software-src/riscv-isa-sim issues 2511-2525 and 2527. The reproducer is in [davidharrishmc/spike-repros](https://github.com/davidharrishmc/spike-repros/tree/main/spike-debug-spec).
