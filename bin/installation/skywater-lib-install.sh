#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified: James Stine, james.stine@okstate.edu, 5 Nov 2025
##
## Purpose: Install OSU SKY130 Standard-Cell Library
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

SKYWATER_LIB_VERSION=3e7dac7af98731b59982f99df6a71e979a44bff7 # Last commit as of Nov. 5, 2025

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# OSU Skywater 130 cell library (https://github.com/stineje/sky130_osu_sc_t12)
# The OSU Skywater 130 cell library is a standard cell library that is used to synthesize Wally.
section_header "Installing/Updating OSU Skywater 130 cell library"
STATUS="osu_skywater_130_cell_library"
mkdir -p "$RISCV"/cad/lib
cd "$RISCV"/cad/lib
if check_tool_version $SKYWATER_LIB_VERSION; then
    rm -rf $RISCV/cad/lib/sky130_osu_sc_t12
    git_checkout "sky130_osu_sc_t12" "https://github.com/stineje/sky130_osu_sc_t12" "$SKYWATER_LIB_VERSION"
    echo "$SKYWATER_LIB_VERSION" > "$RISCV"/versions/$STATUS.version
    echo -e "${SUCCESS_COLOR}OSU Skywater library successfully installed!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}OSU Skywater library already up to date.${ENDC}"
fi
