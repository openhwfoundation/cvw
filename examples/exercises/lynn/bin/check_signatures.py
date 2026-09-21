#!/usr/bin/env -S uv run --script
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26

"""
check_signatures.py

EOF-safe signature comparison with CANARY termination.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# =========================
# USER-CONFIGURABLE CANARY
# =========================
CANARY = "6f5ca309"   # <-- set this to whatever you want


def read_signature_lines(p: Path) -> list[str]:
    lines: list[str] = []
    with p.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if s:
                lines.append(s)
    return lines


def compare_with_canary(got: list[str], exp: list[str]):
    """
    Returns:
      None on PASS
      (line_no, got, exp, reason) on FAIL
    """
    i = 0
    last_line = None

    while True:
        got_eof = i >= len(got)
        exp_eof = i >= len(exp)

        # --- EOF handling ---
        if got_eof or exp_eof:
            if last_line == CANARY:
                return None  # PASS due to CANARY termination
            else:
                g = "<EOF>" if got_eof else got[i]
                e = "<EOF>" if exp_eof else exp[i]
                return (i + 1, g, e, "EOF before CANARY")

        # --- Normal comparison ---
        if got[i] != exp[i]:
            return (i + 1, got[i], exp[i], "value mismatch")

        last_line = got[i]
        i += 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wally", default=os.environ.get("WALLY", ""))
    parser.add_argument("--runs-dir", default="work/runs")
    parser.add_argument("--pattern", default="*.elf.signature")
    args = parser.parse_args()

    if not args.wally:
        print("ERROR: $WALLY not set and --wally not provided", file=sys.stderr)
        return 2

    wally = Path(args.wally).resolve()
    runs_dir = Path(args.runs_dir).resolve()

    sigs = sorted(runs_dir.glob(args.pattern))
    if not sigs:
        print("ERROR: no signature files found", file=sys.stderr)
        return 2

    any_fail = False

    for gen_sig in sigs:
        testname = gen_sig.name.removesuffix(".elf.signature")

        ref_sig = (
            wally
            / "tests/riscof/riscof_work/arch32/rv32i_m/I/src"
            / testname
            / "ref/Reference-sail_c_simulator.signature"
        )

        ref_log = (
            wally
            / "tests/riscof/riscof_work/arch32/rv32i_m/I/src"
            / testname
            / "ref"
            / f"{testname}.log"
        )

        if not ref_sig.exists():
            any_fail = True
            print(f"FAIL {testname}: missing reference signature")
            print(f"  log: {ref_log}")
            continue

        got = read_signature_lines(gen_sig)
        exp = read_signature_lines(ref_sig)

        result = compare_with_canary(got, exp)

        if result is None:
            print(f"PASS {testname}")
        else:
            any_fail = True
            line, g, e, reason = result
            print(f"FAIL {testname}: line {line} ({reason})")
            print(f"  got     : {g}")
            print(f"  expected: {e}")
            print(f"  log: {ref_log}")

    return 1 if any_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
