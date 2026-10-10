#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: March 22 2026
## Modified:
##
## Purpose: Whisper ISS installation script
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

WHISPER_VERSION=ffa61c2bd8b331bb6f31161f0223a114a59c21a9 # Latest commit as of July 13, 2026

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# Boost (https://www.boost.org/)
# The Boost C++ library is required by Whisper. A recent version compiled with C++20 is needed.
source "$WALLY"/bin/installation/boost-install.sh

# Whisper (https://github.com/tenstorrent/whisper)
# Whisper is a RISC-V instruction set simulator (ISS) developed by Tenstorrent.
section_header "Installing/Updating Whisper"
STATUS="whisper"
cd "$RISCV"
if check_tool_version $WHISPER_VERSION; then
    git_checkout "whisper" "https://github.com/tenstorrent/whisper" "$WHISPER_VERSION"
    cd "$RISCV"/whisper
    git submodule update --init --recursive
    make BOOST_DIR="$RISCV" -j"${NUM_THREADS}" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    make BOOST_DIR="$RISCV" INSTALL_DIR="$RISCV/bin" install 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    if [ "$clean" = true ]; then
        cd "$RISCV"
        rm -rf whisper
    fi
    echo "$WHISPER_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}Whisper successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}Whisper already up to date.${ENDC}"
fi
