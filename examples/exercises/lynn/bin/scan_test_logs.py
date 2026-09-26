#!/usr/bin/env -S uv run --script
# James Kaden Cassidy
# kacassidy@hmc.edu
# Dec 25 2025

import argparse
import sys
from pathlib import Path

COMPLETED_STR = "INFO: Test Completed!"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sail", default=0, type=int)
    args = parser.parse_args()

    runs_dir = Path("work")
    if not runs_dir.exists():
        print(f"ERROR: directory not found: {runs_dir}")
        return 2

    pattern = "*.sail.log" if args.sail == 1 else "*.sim.log"
    log_files = sorted(runs_dir.rglob(pattern))
    if not log_files:
        print("No .log files found.")
        return 0

    passed = []
    failed = []
    not_completed_unclassified = [] # no "Test Completed" (non-sail), or missing SUCCESS/FAILURE (sail)
    unreadable = []

    for log in log_files:
        try:
            text = log.read_text(errors="ignore")
        except Exception as e:
            print(f"ERROR: could not read {log}: {e}")
            unreadable.append(log)
            continue

        if args.sail == 1:
            has_success = "SUCCESS" in text
            has_failure = "FAILURE" in text

            if has_failure:
                failed.append(log)
            elif has_success:
                passed.append(log)
            else:
                not_completed_unclassified.append(log)

        else:
            # Failure if either "FAILED" or "Failed" appears anywhere
            has_failed_word = ("FAILED" in text) or ("Failed" in text)
            has_completed = COMPLETED_STR in text

            if has_failed_word:
                failed.append(log)
            elif has_completed:
                passed.append(log)
            else:
                not_completed_unclassified.append(log)

    # ---- Report ----
    print("=== Test Log Summary ===")
    print(f"Total logs:                 {len(log_files)}")
    print(f"Passed:                     {len(passed)}")
    print(f"Failed:                     {len(failed)}")

    if args.sail == 1:
        print(f"Missing SUCCESS/FAILURE:    {len(not_completed_unclassified)}")
    else:
        print(f"Missing 'Completed':        {len(not_completed_unclassified)}")

    print(f"Unreadable:                 {len(unreadable)}")
    print()

    if failed:
        print("❌ Failed tests:")
        for f in failed:
            print(f"  {f.resolve()}")
        print()

    if passed:
        print("✅ Passed tests:")
        for p in passed:
            print(f"  {p.resolve()}")
        print()

    if not_completed_unclassified:
        if args.sail == 1:
            print("⚠️  Logs with no SUCCESS/FAILURE marker:")
        else:
            print(f"⚠️  Logs without '{COMPLETED_STR}':")
        for u in not_completed_unclassified:
            print(f"  {u.resolve()}")
        print()

    if unreadable:
        print("⚠️  Unreadable logs:")
        for u in unreadable:
            print(f"  {u.resolve()}")
        print()

    # Exit status: fail build if any test failed
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
