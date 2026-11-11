# Superscalar benchmarking: CoreMark + Design Compiler

How to measure the dual-issue core's performance, area and timing, and how the numbers are
recorded so successive versions can be compared.

Results accumulate in **`benchmarks/ppa_history.csv`** (tracked in git). One row per run.

---

## The two commands

```bash
source setup.sh                                  # required once per shell

bin/ppa --sim-only --note "what changed"         # CoreMark only, ~40 s
bin/ppa -b        --note "what changed"          # CoreMark + synthesis, ~15 min, detached
```

`--sim-only` is the everyday loop after an RTL edit. The full run is for milestones.

Add `-b` / `--background` to either to detach: the shell returns immediately and output goes to
`benchmarks/ppa_logs/ppa_<timestamp>.log`.

```bash
tail -f benchmarks/ppa_logs/ppa_*.log            # follow a detached run
```

### Options

| Flag | Default | Notes |
|---|---|---|
| `--sim-only` | off | skip synthesis |
| `-b`, `--background` | off | detach, log to `benchmarks/ppa_logs/` |
| `--config` | `rv32gc` | simulation config; CoreMark is rebuilt if the ELF width differs |
| `--synth-config` | `syn_<config>` | the `syn_*` derivatives shrink caches/memories for tractable synthesis |
| `--maxopt` | `0` | see below |
| `--note` | empty | free text recorded in the row |

`FREQ=10000` and `MAXCORES=8` are **hardcoded, not flags** — changing either would make new rows
incomparable with every existing one.

---

## What lands in the CSV

Every run appends exactly one row.

| Columns | `--sim-only` | full run |
|---|---|---|
| `date` `githash` `branch` `dirty` `note` `config` `xlen` `tech` `freq_mhz` `maxopt` | yes | yes |
| `coremark_ticks` `minstret` `cm_per_mhz` `retired` `paired` `dual_issue_pct` | yes | yes |
| `design_area` `crit_path_ns` `fmax_mhz` `crit_unit` `unit_paths` | blank | yes |
| `exec_time_ms` | blank | yes |

`exec_time_ms = coremark_ticks / fmax_mhz` is the only column needing both halves, which is why
`--sim-only` rows leave it blank. It is the figure of merit: cycle count can improve while
execution time gets worse if the clock slows by more than the cycles gained.

`dirty` records whether `src`, `testbench` or `config` had uncommitted changes. If it says `yes`,
the git hash alone does not identify what was measured.

---

## maxopt: strong synthesis vs. knowing where the path is

| | `--maxopt 0` (default) | `--maxopt 1` |
|---|---|---|
| Design Compiler | hierarchical | `ungroup -all -flatten`, `compile_ultra -retime`, `optimize_registers` |
| Runtime | ~11 min | ~90 min |
| Area / Fmax | less optimized | best |
| `crit_unit`, `unit_paths` | **populated** | empty — flattening removes the hierarchy those reports need |

Use `maxopt=0` to find out which unit owns the critical path, `maxopt=1` for a best-case area and
frequency headline.

**Only compare rows sharing the same `maxopt`.** `bin/ppa` enforces this when printing deltas, and
there is a concrete reason: measured on the same two designs, the two modes disagreed on the *sign*
of the critical-path change (see the recorded rows for `d3cd2806c` and `eb22057f9`). Flatten plus
retime lands in a different local optimum per run and is not stable enough for a design-to-design
frequency comparison.

---

## Behaviour worth knowing

- **A failing run is not recorded.** If CoreMark does not print `Correct operation validated`,
  `bin/ppa` exits without appending, so a core that is fast because it is wrong cannot log a good
  number.
- **Deltas compare like with like.** The printed comparison picks the most recent earlier row with
  the same `config` *and* `maxopt`.
- **CoreMark width.** `benchmarks/coremark/Makefile` defaults to `XLEN ?= 32`, and both widths build
  to the same `work/coremark.bare.riscv`. `bin/ppa` checks the ELF width and rebuilds when needed;
  running a mismatched ELF livelocks at PC 0.

---

## The underlying commands

`bin/ppa` runs these for you. Useful when debugging the flow itself.

```bash
# CoreMark
make -C $WALLY/benchmarks/coremark XLEN=32
wsim rv32gc --elf $WALLY/benchmarks/coremark/work/coremark.bare.riscv --test coremark --sim verilator

# Synthesis -- must run from synthDC/, the Makefile uses relative ../src
cd $WALLY/synthDC
make synth DESIGN=wallypipelinedcore CONFIG=syn_rv32gc TECH=sky130 \
     FREQ=10000 MAXOPT=0 MAXCORES=8
```

Reports land in `synthDC/runs/wallypipelinedcore_<config>_orig_<tech>nm_<freq>_MHz_<date>__<githash>/reports/`:

| Report | Used for |
|---|---|
| `qor.rep` | `Design Area` and `Critical Path Length`; `Fmax = 1000 / Critical Path Length` |
| `per_module_timing.rep` | worst path through `ifu`, `ieu`, `lsu`, `hzu`, `mdu`, `priv`, `Stall*` (`maxopt=0` only) |
| `area.rep` | per-unit area (`maxopt=0` only) |
| `timing.rep` | full worst-path detail |

Note the run directory name does **not** encode `MAXOPT`, only a minute-resolution timestamp.

### Environment

Verified present on this machine:

- Design Compiler `W-2024.09-SP3` at `/cad/synopsys/SYN`, `dc_shell-xg-t` on `PATH`
- License `SNPSLMD_LICENSE_FILE=27020@zircon.eng.hmc.edu`, with `SNPSLMD_QUEUE=1` so runs block
  rather than fail when licenses are busy
- **sky130 is the only usable technology.** `sky90` and `tsmc28` library roots are absent, so
  `TECH=sky130` (the default) is the only option
- New RTL files need no registration: `synthDC/scripts/synth.tcl` globs `src/*/*.sv`

---

## Measuring a different commit as a baseline

The superscalar changes are not behind a config parameter, so comparing against single-issue Wally
means checking out an earlier commit. A worktree keeps the current tree untouched:

```bash
git worktree add --detach /tmp/wally-baseline d3cd2806c   # pre-superscalar upstream merge
cd /tmp/wally-baseline
rm -rf addins && ln -s $WALLY/addins addins               # worktrees do not populate submodules
ln -sfn $WALLY/benchmarks/coremark/work benchmarks/coremark/work
ln -s $WALLY/config/deriv config/deriv
export WALLY=$PWD
./bin/wsim rv32gc coremark --sim verilator
cd synthDC && make synth DESIGN=wallypipelinedcore CONFIG=syn_rv32gc TECH=sky130 \
     FREQ=10000 MAXOPT=0 MAXCORES=8
```

Results have to be added to the CSV by hand, since `bin/ppa` reads the git hash of the tree it runs
in. Pick the baseline commit carefully: `d3cd2806c` is pre-superscalar, whereas `21161fa7d`
(step 2) already contains the second decoder, second controller and extra register-file ports, so
most of the area cost is already present there.
