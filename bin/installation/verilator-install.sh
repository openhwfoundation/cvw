#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: Verilator installation script
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

VERILATOR_VERSION=v5.036 # Last release as of May 30, 2025

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# Mold needed for Verilator, not available in all package managers.
if (( UBUNTU_VERSION == 20  || DEBIAN_VERSION == 11 )) || (( SUSE_VERSION < 160 )); then
    STATUS="mold"
    if [ ! -e "$RISCV"/bin/mold ]; then
        section_header "Installing mold"
        cd "$RISCV"
        wget -nv --retry-connrefused $retry_on_host_error --output-document=mold.tar.gz https://github.com/rui314/mold/releases/download/v2.34.1/mold-2.34.1-x86_64-linux.tar.gz
        tar xz --directory="$RISCV" --strip-components=1 -f mold.tar.gz
        rm -f mold.tar.gz
        echo -e "${SUCCESS_COLOR}Mold successfully installed/updated!${ENDC}"
    else
        echo -e "${SUCCESS_COLOR}Mold already installed.${ENDC}"
    fi
fi

# Verilator (https://github.com/verilator/verilator)
# Verilator is a fast open-source Verilog simulator that compiles synthesizable Verilog code into C++ code.
# It is used for linting and simulation of Wally.
# Verilator needs to be built from source to get the latest version (Wally needs 5.021 or later).
section_header "Installing/Updating Verilator"
STATUS="verilator"
cd "$RISCV"
if check_tool_version $VERILATOR_VERSION; then
    git_checkout "verilator" "https://github.com/verilator/verilator" "$VERILATOR_VERSION"
    unset VERILATOR_ROOT
    cd "$RISCV"/verilator
    autoconf
    ./configure --prefix="$RISCV"
    make -j "${NUM_THREADS}" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    make install 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    if [ "$clean" = true ]; then
        cd "$RISCV"
        rm -rf verilator
    fi
    echo "$VERILATOR_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}Verilator successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}Verilator already up to date.${ENDC}"
fi
