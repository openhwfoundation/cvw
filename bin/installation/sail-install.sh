#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: Sail installation script
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

RISCV_SAIL_MODEL_VERSION=0.10 # Last release as of Feb 16, 2026

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# RISC-V Sail Model (https://github.com/riscv/sail-riscv)
# The RISC-V Sail Model is the golden reference model for RISC-V.
# It is written in Sail, a formal specification language designed for describing the semantics of an ISA.
section_header "Installing/Updating RISC-V Sail Model"
STATUS="riscv-sail-model"
cd "$RISCV"
if check_tool_version $RISCV_SAIL_MODEL_VERSION; then
    wget -nv --retry-connrefused $retry_on_host_error --output-document=sail-riscv.tar.gz "https://github.com/riscv/sail-riscv/releases/download/$RISCV_SAIL_MODEL_VERSION/sail-riscv-$(uname)-$(arch).tar.gz"
    tar xz --directory="$RISCV" --strip-components=1 -f sail-riscv.tar.gz
    rm -f sail-riscv.tar.gz
    echo "$RISCV_SAIL_MODEL_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}RISC-V Sail Model successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}RISC-V Sail Model already up to date.${ENDC}"
fi
