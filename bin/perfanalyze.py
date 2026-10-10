#!/usr/bin/env python3
#
# perfanalyze.py
# David_Harris@hmc.edu 10 October 2026
#
# Analyze the cycle accounting that bin/perfsweep collects with the testbench performance
# monitor (testbench/common/perfmon.sv) and report lost cycles that may come from RTL defects.
#
# usage: perfanalyze.py SWEEPDIR [-o REPORT.md] [-n TOP]
#   SWEEPDIR holds one subdirectory per configuration with <dir>.csv and <dir>pc.csv files.
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

import argparse
import bisect
import collections
import csv
import glob
import os
import statistics
import subprocess
import sys

# Lost cycles inside these functions come from the test infrastructure, not the core under test:
# they poll the UART line status register while printing (the ACT result line, benchmark printf).
WAIVED_FUNCTIONS = {"rvmodel_io_write_str", "vprintfmt", "vprintfmt.constprop.1", "putchar", "uart_putc"}

NONCAUSE_COLUMNS = ("elf", "cycles", "instret", "lost")
OBJDUMP = os.environ.get("OBJDUMP", "riscv64-unknown-elf-objdump")
NM = os.environ.get("NM", "riscv64-unknown-elf-nm")


class Symbols:
    """Function lookup and disassembly for the ELFs in a sweep, cached per ELF."""

    def __init__(self):
        self.syms = {}
        self.dis = {}

    def function(self, elf, pc):
        if elf not in self.syms:
            out = subprocess.run([NM, "-n", elf], capture_output=True, text=True).stdout
            table = []
            for line in out.splitlines():
                fields = line.split()
                if len(fields) == 3 and fields[1] in "tTdDbBrR":
                    table.append((int(fields[0], 16), fields[2]))
            self.syms[elf] = ([a for a, _ in table], [n for _, n in table])
        addrs, names = self.syms[elf]
        i = bisect.bisect_right(addrs, pc) - 1
        return names[i] if i >= 0 else "?"

    def instruction(self, elf, pc):
        key = (elf, pc)
        if key not in self.dis:
            out = subprocess.run([OBJDUMP, "-d", f"--start-address={pc:#x}", f"--stop-address={pc + 4:#x}", elf],
                                 capture_output=True, text=True).stdout
            text = "?"
            for line in out.splitlines():
                if line.strip().startswith(f"{pc:x}:"):
                    text = " ".join(line.split("\t")[2:]).strip()
            self.dis[key] = text
        return self.dis[key]


def read_sweep(sweepdir):
    """Return {config: [row dicts]} and {config: [(elf, pc, cause, cycles)]}."""
    rows, pcs = collections.defaultdict(list), collections.defaultdict(list)
    for cfgdir in sorted(glob.glob(os.path.join(sweepdir, "*/"))):
        config = os.path.basename(os.path.normpath(cfgdir))
        for f in sorted(glob.glob(os.path.join(cfgdir, "*.csv"))):
            if f.endswith("pc.csv"):
                with open(f) as fh:
                    pcs[config] += [(e, int(p, 16), c, int(n)) for e, p, c, n in csv.reader(fh)]
            else:
                with open(f) as fh:
                    rows[config] += list(csv.DictReader(fh))
    return rows, pcs


def cause_columns(row):
    extra = ("falsedep_", "bp_", "ep_", "hpm", "icache_", "dcache_")
    return [k for k in row if k not in NONCAUSE_COLUMNS and not k.startswith(extra)]


def test_name(elf):
    return os.path.basename(elf).removesuffix(".elf")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sweepdir")
    parser.add_argument("-o", "--output", default=None, help="Markdown report (default SWEEPDIR/perf_report.md)")
    parser.add_argument("-n", "--top", type=int, default=15)
    args = parser.parse_args()
    out_path = args.output or os.path.join(args.sweepdir, "perf_report.md")
    rows, pcs = read_sweep(args.sweepdir)
    if not rows:
        sys.exit("perfanalyze: no results found")
    sym = Symbols()
    lines = ["# Performance monitor report", ""]

    for config in sorted(rows):
        rs = rows[config]
        causes = cause_columns(rs[0])
        lines += [f"## {config}", "", f"{len(rs)} ELFs.", ""]

        # 1. Accounting identity and unexplained cycles
        bad = [r["elf"] for r in rs if int(r["lost"]) != sum(int(r[c]) for c in causes)]
        unknown = [(r["elf"], int(r["unknown"])) for r in rs if int(r.get("unknown", 0))]
        lines += ["### Accounting checks", "",
                  f"- ELFs whose lost cycles do not equal the sum of causes: {len(bad)}",
                  f"- ELFs with cycles charged to no cause (unknown): {len(unknown)}"]
        for e, n in unknown[:args.top]:
            lines.append(f"  - {test_name(e)}: {n}")
        lines.append("")

        # 2. Lost cycles by cause, with infrastructure cycles separated out
        waived = collections.Counter()
        by_cause_pc = collections.defaultdict(collections.Counter)
        for elf, pc, cause, n in pcs[config]:
            if sym.function(elf, pc) in WAIVED_FUNCTIONS:
                waived[cause] += n
            else:
                by_cause_pc[cause][(elf, pc)] += n
        total = {c: sum(int(r[c]) for r in rs) for c in causes}
        cycles = sum(int(r["cycles"]) for r in rs)
        instret = sum(int(r["instret"]) for r in rs)
        lines += ["### Lost cycles by cause", "",
                  f"Cycles {cycles}, instructions {instret}, CPI {cycles / max(instret, 1):.3f}. "
                  f"Waived (test infrastructure: {', '.join(sorted(WAIVED_FUNCTIONS))}): {sum(waived.values())} cycles.", "",
                  "| cause | cycles | waived | per 1000 instr (unwaived) |", "|---|---|---|---|"]
        for c in sorted(causes, key=lambda c: -total[c]):
            if total[c]:
                lines.append(f"| {c} | {total[c]} | {waived[c]} | {1000 * (total[c] - waived[c]) / max(instret, 1):.1f} |")
        lines.append("")

        # 3. False dependencies (MatchDE compares register fields the instruction does not use)
        fd = {k: sum(int(r[k]) for r in rs) for k in rs[0] if k.startswith("falsedep_") and k != "falsedep_nointwrite"}
        fd_noint = sum(int(r.get("falsedep_nointwrite", 0)) for r in rs)
        lines += ["### Structural stalls without a true integer dependency", "",
                  ", ".join(f"{k.removeprefix('falsedep_')}: {v}" for k, v in fd.items()) +
                  f" (out of {total.get('loaduse', 0)} load-use, {total.get('csrrd', 0)} CSR-read, "
                  f"{total.get('mdu', 0)} MDU, {total.get('fcvtint', 0)} fcvt-int bubble cycles). "
                  f"{fd_noint} of them follow an instruction that writes no integer register (e.g. an FP load); "
                  f"the rest match a register field the decode-stage instruction does not read.", ""]
        worst = sorted(rs, key=lambda r: -sum(int(r[k]) for k in fd))[:5]
        for r in worst:
            n = sum(int(r[k]) for k in fd)
            if n:
                lines.append(f"- {test_name(r['elf'])}: {n}")
        lines.append("")

        # 4. HPM event cross-checks (counter events vs the monitor's own measurements)
        def tot(k):
            return sum(int(r[k]) for r in rs)
        checks = [("hpm0 (mcycle) = cycles", tot("hpm0"), cycles),
                  ("hpm2 (minstret) = retired", tot("hpm2"), instret),
                  ("hpm6 (BP wrong, retired) vs misprediction flushes", tot("hpm6"), tot("bp_flushes")),
                  ("2 x misprediction flushes vs bpwrong bubble cycles", 2 * tot("bp_flushes"), total.get("bpwrong", 0)),
                  ("hpm15 (D$ miss cycles) = D$ stall cycles", tot("hpm15"), tot("ep_dcache_sum")),
                  ("hpm18 (I$ miss cycles) = I$ stall cycles", tot("hpm18"), tot("ep_icache_sum")),
                  ("hpm24 (divide cycles) = divide busy cycles", tot("hpm24"), tot("ep_div_sum")),
                  ("hpm11 (load stalls) vs load-use bubbles", tot("hpm11"), total.get("loaduse", 0)),
                  ("hpm12 (store stalls) vs store-load bubbles", tot("hpm12"), total.get("storeload", 0))]
        lines += ["### Counter event cross-checks", "", "| check | counter | monitor | ratio |", "|---|---|---|---|"]
        for name, a, b in checks:
            ratio = f"{a / b:.3f}" if b else ("-" if a == 0 else "inf")
            flag = "" if a == b else " **differs**"
            lines.append(f"| {name}{flag} | {a} | {b} | {ratio} |")
        lines.append("")

        # 5. Stall episodes: typical and longest lengths, and the longest ones by ELF
        lines += ["### Stall episodes", "", "| episode | count | mean | longest | longest in |", "|---|---|---|---|---|"]
        for ep in ("dcache", "icache", "hptw", "div", "lsubus", "ifubus", "spillm", "spillf"):
            n, s = tot(f"ep_{ep}_n"), tot(f"ep_{ep}_sum")
            if not n:
                continue
            r = max(rs, key=lambda r: int(r[f"ep_{ep}_max"]))
            pc = int(r[f"ep_{ep}_maxpc"], 16)
            lines.append(f"| {ep} | {n} | {s / n:.1f} | {r[f'ep_{ep}_max']} | {test_name(r['elf'])} @{pc:x} {sym.function(r['elf'], pc)} |")
        lines.append("")

        # 5b. Cache stall episodes by kind, fills the counters do not report, and repeated fills
        lines += ["### Cache stall episodes", "",
                  "| cache | clean fills | dirty fills | flushes | CMO writebacks | cancelled by flush or walk | other | fills done | "
                  "fills not reported as misses | re-fills |",
                  "|---|---|---|---|---|---|---|---|---|---|"]
        for k in ("icache", "dcache"):
            lines.append(f"| {k} | {tot(k + '_fill')} | {tot(k + '_fill_dirty')} | {tot(k + '_flush_eps')} | {tot(k + '_cmo_eps')} | {tot(k + '_cancel_eps')} | "
                         f"{tot(k + '_other_eps')} | {tot(k + '_fills_done')} | {tot(k + '_fills_unreported')} | "
                         f"{tot(k + '_refill')} |")
        lines += ["", f"- hpm17 (I$ misses) {tot('hpm17')} vs I$ fills done - unreported "
                      f"{tot('icache_fills_done') - tot('icache_fills_unreported')}",
                  f"- hpm14 (D$ misses) {tot('hpm14')} vs D$ fills done - unreported "
                  f"{tot('dcache_fills_done') - tot('dcache_fills_unreported')}"]
        for k in ("icache", "dcache"):
            worst = sorted(rs, key=lambda r: -int(r[f"{k}_other_eps"]))[:5]
            for r in worst:
                if int(r[f"{k}_other_eps"]):
                    pc = int(r[f"{k}_other_pc"], 16)
                    lines.append(f"  - {k} stall without fill, flush, writeback, cancelling flush or walk: {test_name(r['elf'])}: {r[f'{k}_other_eps']} episodes, "
                                 f"longest {r[f'{k}_other_max']} @{pc:x} {sym.function(r['elf'], pc)}")
        lines.append("")

        # 6. Hot spots by cause (unwaived)
        lines += ["### Largest unwaived lost-cycle sites", ""]
        for c in sorted(by_cause_pc, key=lambda c: -sum(by_cause_pc[c].values())):
            sites = collections.Counter()
            for (elf, pc), n in by_cause_pc[c].items():
                sites[(sym.function(elf, pc), pc & 0xfff, elf)] += n
            agg = collections.Counter()
            example = {}
            for (fn, off, elf), n in sites.items():
                agg[fn] += n
                example.setdefault(fn, (elf, off))
            lines.append(f"- **{c}** ({sum(by_cause_pc[c].values())} cycles): " +
                         "; ".join(f"{fn} {n}" for fn, n in agg.most_common(5)))
        lines.append("")

        # 7. Per-directory outliers: lost cycles per instruction far above the directory median
        groups = collections.defaultdict(list)
        for r in rs:
            groups[os.path.basename(os.path.dirname(r["elf"]))].append(r)
        out = []
        for g, members in groups.items():
            vals = [(int(r["lost"]) - 0) / max(int(r["instret"]), 1) for r in members]
            if len(vals) < 4:
                continue
            med = statistics.median(vals)
            mad = statistics.median(abs(v - med) for v in vals) or 1e-9
            for r, v in zip(members, vals):
                if (v - med) / mad > 8 and v > 1.5 * med:
                    out.append((v / med, g, test_name(r["elf"]), v, med))
        lines += ["### Per-directory outliers (lost cycles per instruction)", ""]
        for ratio, g, t, v, med in sorted(out, reverse=True)[:args.top]:
            lines.append(f"- {g}/{t}: {v:.2f} vs directory median {med:.2f} ({ratio:.1f}x)")
        lines.append("")

    # 8. Same test across configurations
    if len(rows) > 1:
        cfgs = sorted(rows)
        by = {c: {test_name(r["elf"]): r for r in rows[c]} for c in cfgs}
        common = set.intersection(*(set(b) for b in by.values()))
        lines += [f"## {' vs '.join(cfgs)}", "", f"{len(common)} tests in common.", ""]
        diffs = []
        for t in common:
            a, b = by[cfgs[0]][t], by[cfgs[1]][t]
            ia, ib = int(a["instret"]), int(b["instret"])
            if ia and ib:
                diffs.append(((int(a["lost"]) / ia) / max(int(b["lost"]) / ib, 1e-9), t))
        diffs.sort()
        lines.append(f"Lost cycles per instruction, {cfgs[0]} / {cfgs[1]}: median {statistics.median(d for d, _ in diffs):.2f}; "
                     f"extremes: " + ", ".join(f"{t} {d:.2f}" for d, t in diffs[:3] + diffs[-3:]))
        lines.append("")

    with open(out_path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"perfanalyze: wrote {out_path}")


if __name__ == "__main__":
    main()
