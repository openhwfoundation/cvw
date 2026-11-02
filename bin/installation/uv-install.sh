#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: January 19 2026
## Modified:
##
## Purpose: uv/Python installation script
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

UV_VERSION=0.12.23 # Latest release as of October 7, 2026

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# uv (https://docs.astral.sh/uv/)
# uv is a Python package manager and virtual environment tool.
section_header "Installing/Updating uv"
STATUS="uv"
cd "$RISCV"
if check_tool_version $UV_VERSION; then
    curl -LsSf https://astral.sh/uv/$UV_VERSION/install.sh | env UV_INSTALL_DIR="$RISCV/bin" UV_NO_MODIFY_PATH=1 sh
    echo "$UV_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}uv successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}uv already up to date.${ENDC}"
fi
