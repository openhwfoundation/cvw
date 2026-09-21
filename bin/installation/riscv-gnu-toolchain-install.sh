#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: RISC-V GNU Toolchain installation script
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https:##solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################

RISCV_GNU_TOOLCHAIN_VERSION=311e70f6c55953a624ca670de7c85af38c2b23c2 # Latest commit as of January 22, 2026 (GCC 15.2, Binutils 2.45)
set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# RISC-V GNU Toolchain (https://github.com/riscv-collab/riscv-gnu-toolchain)
# The RISC-V GNU Toolchain includes the GNU Compiler Collection (gcc), GNU Binutils, Newlib,
# and the GNU Debugger Project (gdb). It is a collection of tools used to compile RISC-V programs.
# To install GCC from source can take hours to compile.
# This configuration enables multilib to target many flavors of RISC-V.
# This book is tested with GCC 13.2.0 and 14.2.0.
section_header "Installing/Updating RISC-V GNU Toolchain"
STATUS="riscv-gnu-toolchain"
cd "$RISCV"
if check_tool_version $RISCV_GNU_TOOLCHAIN_VERSION; then
    git_checkout "riscv-gnu-toolchain" "https://github.com/riscv/riscv-gnu-toolchain" "$RISCV_GNU_TOOLCHAIN_VERSION"
    cd "$RISCV"/riscv-gnu-toolchain
    ./configure --prefix="${RISCV}" --with-multilib-generator="rv32e-ilp32e--;rv32i-ilp32--;rv32im-ilp32--;rv32iac-ilp32--;rv32imac-ilp32--;rv32imafc-ilp32f--;rv32imafdc-ilp32d--;rv64i-lp64--;rv64ic-lp64--;rv64iac-lp64--;rv64imac-lp64--;rv64imafdc-lp64d--;rv64im-lp64--;"
    make -j "${NUM_THREADS}" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    if [ "$clean" = true ]; then
        cd "$RISCV"
        rm -rf riscv-gnu-toolchain
    fi
    echo "$RISCV_GNU_TOOLCHAIN_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}RISC-V GNU Toolchain successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}RISC-V GNU Toolchain already up to date.${ENDC}"
fi
