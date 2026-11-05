#!/bin/bash
###########################################
## openocd debug install script.
##
## Written: James Stine, james.stine@okstate.edu
## Created: Oct 16, 2025
##
## Purpose: openocd installation script
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

OPENOCD_VERSION=eb01c632a4bb1c07d2bddb008d6987c809f1c496 # Last commit as of 2025-10-09T10:08:18Z

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# openocd (https://github.com/riscv-collab/riscv-openocd)
# openocd is OpenOCD stands for Open On-Chip Debugger and is an open-source tool that provides
# on-chip programming, debugging, and boundary-scan testing for embedded systems.
section_header "Installing/Updating OpenOCD"
STATUS="openocd"
cd "$RISCV"
if check_tool_version $OPENOCD_VERSION; then
    git_checkout "riscv-openocd" "https://github.com/riscv-collab/riscv-openocd.git" "$OPENOCD_VERSION"
    cd "$RISCV"/riscv-openocd
    git submodule update --init --recursive
    ./bootstrap
    ./configure --enable-ftdi --enable-dummy --enable-jimtcl --prefix="$RISCV"
    make -j "${NUM_THREADS}" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    sudo make install 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    echo "$OPENOCD_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}openocd successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}openocd already up to date.${ENDC}"
fi
