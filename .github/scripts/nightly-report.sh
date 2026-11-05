#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Write the body of the nightly-failure issue: what failed, and how to reproduce it locally with the
# same commit and tool versions.
# Usage: nightly-report.sh <regression log> <output Markdown file>
# Run from the cvw checkout the nightly ran in, after its tools are on PATH.

set -euo pipefail

log="${1:?Usage: nightly-report.sh <regression log> <output file>}"
out="${2:?Usage: nightly-report.sh <regression log> <output file>}"
workspace="${GITHUB_WORKSPACE:-$PWD}"
sha="$(git rev-parse HEAD)"
fence='```'

# The value an installer script in bin/installation pins, e.g. pin verilator-install.sh VERILATOR_VERSION
pin() { sed -n "s/^$2=\([^ ]*\).*/\1/p" "bin/installation/$1"; }
version() { "$@" 2>&1 | head -1 || echo unknown; }

# regression-wally prints the command of each failing test; show it with $WALLY for the checkout path
plain="$(sed 's/\x1b\[[0-9;]*m//g' "$log" 2>/dev/null || true)"
failures="$(grep -E 'FAIL|Timeout|Execution failed|did not finish|failed' <<<"$plain" | grep -v '^Reproduce with:' | head -50 || true)"
repro="$(sed -n 's/^Reproduce with: //p' <<<"$plain" | sed "s|$workspace|\$WALLY|g" | head -30 || true)"
nrepro="$(grep -c '^Reproduce with: ' <<<"$plain" || true)"

{
  echo "### What failed"
  echo "$fence"
  echo "${failures:-No failure lines found in the regression log; see the run.}"
  echo "$fence"
  echo
  echo "### Versions"
  echo "- cvw: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-openhwfoundation/cvw}/commit/$sha"
  echo "- Submodules:"
  echo "  $fence"
  git submodule status addins/riscv-arch-test addins/embench-iot addins/coremark | sed 's/^/  /'
  echo "  $fence"
  echo "- Verilator $(pin verilator-install.sh VERILATOR_VERSION): \`$(version verilator --version)\`"
  echo "- Sail $(pin sail-install.sh RISCV_SAIL_MODEL_VERSION): \`$(version sail_riscv_sim --version)\`"
  echo "- RISC-V GCC (multilib) riscv-gnu-toolchain $(pin riscv-gnu-toolchain-install.sh RISCV_GNU_TOOLCHAIN_VERSION): \`$(version riscv64-unknown-elf-gcc --version)\`"
  echo "- uv $(pin uv-install.sh UV_VERSION); riscv-arch-test's own tools are pinned in its \`.mise.toml\`"
  echo "- Runner: ${ImageOS:-unknown} ${ImageVersion:-}"
  echo
  echo "### Reproduce"
  echo "The installer scripts at this commit pin the versions above; each one skips a tool already at its version."
  echo "$fence"
  echo "git clone https://github.com/openhwfoundation/cvw && cd cvw"
  echo "git checkout $sha"
  echo "git submodule update --init addins/riscv-arch-test addins/embench-iot addins/coremark"
  echo "bash bin/installation/verilator-install.sh \"\$RISCV\""
  echo "bash bin/installation/sail-install.sh \"\$RISCV\""
  echo "bash bin/installation/riscv-gnu-toolchain-install.sh \"\$RISCV\""
  echo "source setup.sh"
  echo "regression-wally --ci --nightly    # the whole run"
  if [[ -n "$repro" ]]; then
    echo
    echo "# Or only the failing tests, after building the tests they use:"
    echo "make act zsbl coverage deriv"
    echo "$repro"
  fi
  echo "$fence"
  if ((nrepro > 30)); then
    echo "Only the first 30 of $nrepro failing commands are listed; the regression log has the rest."
  fi
} >"$out"
