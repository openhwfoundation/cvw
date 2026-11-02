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
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

VERILATOR_VERSION=60f166e1ef2a52ddbf46df0c5bd88783bd1f4a2b # Commit as of October 19, 2026; no release yet has the covergroup fixes functional coverage needs

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# Mold needed for Verilator, not available in all package managers.
# Only SUSE sets SUSE_VERSION, so the version comparison needs a lower bound to
# avoid matching every other distro, where an unset version reads as 0.
if (( UBUNTU_VERSION == 20 || (SUSE_VERSION > 0 && SUSE_VERSION < 160) )); then
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
    # Verilator needs Python 3.8 or newer, but OpenSUSE 15.6's python3 is 3.6, so use the version installed for Wally
    ./configure --prefix="$RISCV" PYTHON3="${PYTHON_VERSION:-python3}"
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
