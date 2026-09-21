#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: Buildroot and Linux testvector installation script
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

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
    source "${dir}"/activate-tools.sh
fi

# Buildroot and Linux testvectors
# Buildroot is used to boot a minimal version of Linux on Wally.
# Testvectors are generated using QEMU.
section_header "Installing Buildroot and Creating Linux testvectors"
STATUS="buildroot"
export LD_LIBRARY_PATH=$RISCV/lib:$RISCV/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}:$RISCV/riscv64-unknown-elf/lib:$RISCV/lib/x86_64-linux-gnu
cd "$WALLY"/linux
if [ ! -e "$RISCV"/buildroot ]; then
    FORCE_UNSAFE_CONFIGURE=1 make 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ] # FORCE_UNSAFE_CONFIGURE is needed to allow buildroot to compile when run as root
    echo -e "${SUCCESS_COLOR}Buildroot successfully installed and Linux testvectors created!${ENDC}"
elif [ ! -e "$RISCV"/linux-testvectors ]; then
    echo -e "${OK_COLOR}Buildroot already exists, but Linux testvectors are missing. Generating them now.${ENDC}"
    make dumptvs 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    echo -e "${SUCCESS_COLOR}Linux testvectors successfully generated!${ENDC}"
else
    echo -e "${OK_COLOR}Buildroot and Linux testvectors already exist.${ENDC}"
    echo -e "${WARNING_COLOR}Buildroot is not updated automatically. If you want to install a newer version, delete the existing $RISCV/buildroot directory and rerun this script.${ENDC}"
fi
