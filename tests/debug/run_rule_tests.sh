#!/bin/bash
###############################################################################
# run_rule_tests.sh: build and run debug rule tests one at a time
#
# Usage: run_rule_tests.sh [-s questa|verilator] [-x 64|32|both] PATTERN...
#   PATTERN is a test-name glob such as 'WALLY-debug-dm-*'.
# For each matching rv64/rv32 source, generates the vectors serially
# with Spike + OpenOCD (parallel generation truncates vectors), builds
# the memfile, runs wsim on the ELF and its vectors, and prints one
# line per test: PASS, FAIL (signature/DMI counts), GENFAIL or HANG.
# Logs go to build*/rulelogs/<test>.sim.log.
###############################################################################
set -u
SIM=questa
XLENS="64 32"
while getopts "s:x:" o; do
  case $o in
    s) SIM=$OPTARG ;;
    x) case $OPTARG in 64) XLENS=64 ;; 32) XLENS=32 ;; *) XLENS="64 32" ;; esac ;;
    *) exit 2 ;;
  esac
done
shift $((OPTIND-1))
[ $# -ge 1 ] || { sed -n 3,12p "$0"; exit 2; }
: "${WALLY:?source setup.sh first}"
cd "$WALLY/tests/debug" || exit 1
make -s dirs >/dev/null
for x in $XLENS; do
  src=rv$x; build=build; [ $x = 32 ] && build=build32
  mkdir -p $build/rulelogs
  for pat in "$@"; do
    for s in $src/$pat.S; do
      [ -e "$s" ] || continue
      t=$(basename "$s" .S)
      rm -f $build/testvectors/$t.tv
      if ! make -s $build/testvectors/$t.tv > $build/rulelogs/$t.gen.log 2>&1; then
        echo "GENFAIL rv$x $t"; continue
      fi
      make -s -f ../riscof/makefile-memfile WORKDIR=$WALLY/tests/debug/$build \
        ELFFILES=$build/$t.elf OBJDUMPFILES=$build/$t.elf.objdump >/dev/null 2>&1
      (cd "$WALLY" && timeout 600 wsim debug$x tests/debug/$build/$t.elf \
        --debug tests/debug/$build/testvectors/$t.tv --sim $SIM) > $build/rulelogs/$t.sim.log 2>&1
      log=$build/rulelogs/$t.sim.log
      if grep -q "SUCCESS! All tests ran" $log; then echo "PASS rv$x $t"
      elif r=$(grep -m1 -o "FAIL: .*" $log); then echo "FAIL rv$x $t ($r)"
      elif grep -q "Watch Dog" $log; then echo "HANG rv$x $t"
      else echo "ERROR rv$x $t (see $log)"
      fi
    done
  done
done
