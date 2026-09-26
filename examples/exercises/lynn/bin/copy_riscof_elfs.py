#!/usr/bin/env -S uv run --script
# James Kaden Cassidy
# kacassidy@hmc.edu
# 1/22/26

"""
Copy RISCOF ref.elf files into lynn/tests/riscof/<extension>/<test>.elf

Run from: $(WALLY)/examples/exercises/lynn
Example:
  python3 bin/copy_riscof_elves.py --wally "$WALLY" rv32i_m/I rv32i_m/M
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path


def die(msg: str, code: int = 2) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def warn(msg: str) -> None:
    print(f"WARNING: {msg}", file=sys.stderr)


def info(msg: str) -> None:
    print(msg)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Copy RISCOF ref.elf files into lynn/tests/riscof/<extension>/<test>.elf"
    )
    p.add_argument(
        "--wally",
        required=True,
        help="Path to WALLY repo root (e.g. from Makefile: --wally $(WALLY))",
    )
    p.add_argument(
        "extensions",
        nargs="+",
        help="One or more extension strings, used as subfolders under rv32i_m/<extension>/src",
    )
    p.add_argument(
        "--out",
        default=None,
        help="Output base directory (default: <cwd>/tests/riscof). Use if you want a custom output.",
    )
    p.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite destination file if it already exists.",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be copied, but do not write anything.",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()

    # You said: program is run in $(WALLY)/examples/exercises/lynn
    cwd = Path.cwd()

    wally = Path(args.wally).expanduser().resolve()
    if not wally.exists():
        die(f"--wally path does not exist: {wally}")

    out_base = Path(args.out).expanduser().resolve() if args.out else (cwd / "tests" / "riscof")
    # Ensure base output directory exists
    if not args.dry_run:
        out_base.mkdir(parents=True, exist_ok=True)

    total_found = 0
    total_copied = 0
    conflicts = 0

    for ext in args.extensions:
        # Source root for this extension:
        src_root = wally / "tests" / "riscof" / "riscof_work" / "arch32" / "rv32i_m" / ext / "src"
        if not src_root.exists():
            warn(f"Source folder missing for extension '{ext}': {src_root}")
            continue

        # Destination directory for this extension
        dest_dir = out_base / ext
        if not args.dry_run:
            dest_dir.mkdir(parents=True, exist_ok=True)

        # Find all ref.elf files that match */ref/ref.elf under src_root
        # (This should catch <test>/ref/ref.elf even if <test> is nested deeper.)
        matches = list(src_root.rglob("ref/ref.elf"))

        if not matches:
            warn(f"No ref/ref.elf files found under: {src_root}")
            continue

        # Optional: track test name -> source path for duplicate detection within this extension
        seen_tests: dict[str, Path] = {}

        for ref_elf in matches:
            total_found += 1

            # Expect: .../<test>/ref/ref.elf  -> test folder is parent of "ref"
            test_dir = ref_elf.parent.parent
            test_name = test_dir.name

            # Detect duplicates (same test_name found multiple times)
            if test_name in seen_tests and seen_tests[test_name] != ref_elf:
                conflicts += 1
                warn(
                    f"Duplicate test name '{test_name}' for extension '{ext}'.\n"
                    f"  First: {seen_tests[test_name]}\n"
                    f"  Also : {ref_elf}\n"
                    f"  Skipping this one."
                )
                continue
            seen_tests[test_name] = ref_elf

            dest_path = dest_dir / f"{test_name}.elf"

            if dest_path.exists() and not args.overwrite:
                conflicts += 1
                warn(f"Destination exists (use --overwrite to replace): {dest_path}")
                continue

            info(f"[{ext}] {ref_elf} -> {dest_path}")

            if not args.dry_run:
                # Ensure destination directory exists (should already, but safe)
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ref_elf, dest_path)
                total_copied += 1

    info("")
    info(f"Done. Found: {total_found}, Copied: {total_copied}, Conflicts/Skipped: {conflicts}")
    info(f"Output base: {out_base}")


if __name__ == "__main__":
    main()
