#!/usr/bin/env bash
# Run every ACT ELF under <dir> on cv32e40s-tb; PASS iff exit 0 and "ALL TESTS PASSED".
# usage: run-act-dir.sh <cfg> <elf-dir> <log-dir> [run-cv32e40s.sh options...]
set -u
cfg=$1 dir=$2 logs=$3; shift 3
B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$logs"
find -L "$dir" -name '*.elf' | sort | xargs -P "$(nproc)" -I{} bash -c '
  e={}; l="'"$logs"'/$(basename "${e%.elf}").log"
  "'"$B"'/run-cv32e40s.sh" --cfg '"$cfg"' --maxcycles 20000000 "$@" --elf "$e" > "$l" 2>&1
  rc=$?
  if [ $rc -eq 0 ] && grep -q "ALL TESTS PASSED" "$l"; then echo "PASS $(basename $e)"; else echo "FAIL $(basename $e) rc=$rc"; fi
' _ "$@" | sort > "$logs/summary.txt"
echo "$(grep -c ^PASS "$logs/summary.txt") pass, $(grep -c ^FAIL "$logs/summary.txt") fail ($logs/summary.txt)"
