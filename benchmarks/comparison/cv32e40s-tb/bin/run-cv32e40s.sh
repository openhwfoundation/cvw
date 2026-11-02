#!/usr/bin/env bash
# Run one ELF on the cv32e40s-tb Verilator testbench (modelled on cv32e40x-dv's run-cv32e40x.sh).
# usage: run-cv32e40s.sh --cfg <rv32imc|rv32imcb-pma-pmp> [--maxcycles N] [--obi-stall] [--elf] <elf> [+plusargs...]
# The testbench boots at the ELF entry point and $readmemh's the sibling <base>.hex, generated
# here with objcopy. Output through the virtual printer (0x1000_0000) goes to stdout;
# RVMODEL_HALT_PASS prints "ALL TESTS PASSED" (exit 0), RVMODEL_HALT_FAIL "TEST(S) FAILED!" (exit != 0).
set -euo pipefail
CFG="" ELF="" MAXC="${CERT_MAXCYCLES:-200000000}" EXTRA=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cfg) CFG="$2"; shift 2 ;;
    --elf) ELF="$2"; shift 2 ;;
    --maxcycles) MAXC="$2"; shift 2 ;;
    --obi-stall) EXTRA+=("+obi_stall"); shift ;;
    +*) EXTRA+=("$1"); shift ;;
    *) ELF="$1"; shift ;;
  esac
done
: "${CFG:?--cfg required}"; : "${ELF:?ELF required}"
TB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="$TB/build/$CFG/Vtb_top"
[[ -x "$SIM" ]] || { echo "no simulator at $SIM; build with: make -C $TB CFG=$CFG" >&2; exit 2; }
HEX="${ELF%.*}.hex"
if [[ ! -f "$HEX" || "$ELF" -nt "$HEX" ]]; then riscv64-unknown-elf-objcopy -O verilog "$ELF" "$HEX"; fi
exec "$SIM" "+maxcycles=$MAXC" "+elf_file=$ELF" "${EXTRA[@]}"
