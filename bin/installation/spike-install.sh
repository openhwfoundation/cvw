#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: Spike installation script
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

SPIKE_VERSION=76ced61f540a55d6d26a23e6dadd02f83ea634ca # Last commit as of March 23, 2026

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# Spike (https://github.com/riscv-software-src/riscv-isa-sim)
# Spike is a reference model for RISC-V. It is a functional simulator that can be used to run RISC-V programs.
section_header "Installing/Updating SPIKE"
STATUS="spike"
cd "$RISCV"
if check_tool_version $SPIKE_VERSION; then
    git_checkout "riscv-isa-sim" "https://github.com/riscv-software-src/riscv-isa-sim" "$SPIKE_VERSION"
    cd "$RISCV"/riscv-isa-sim
    mkdir -p build
    cd build
    ../configure --prefix="$RISCV"
    make -j "${NUM_THREADS}" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    make install 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    if [ "$clean" = true ]; then
        cd "$RISCV"
        rm -rf riscv-isa-sim
    fi
    echo "$SPIKE_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}Spike successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}Spike already up to date.${ENDC}"
fi
