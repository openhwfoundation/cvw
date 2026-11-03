#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: March 22 2026
## Modified:
##
## Purpose: mise installation script
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
################################################################################################

MISE_VERSION=v2026.3.13 # Latest version as of March 23, 2026

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# mise (https://mise.jdx.dev/)
# mise is a development environment setup tool for managing tool versions and environment variables.
section_header "Installing/Updating mise"
STATUS="mise"
cd "$RISCV"
if check_tool_version $MISE_VERSION; then
    curl -LsSf https://mise.run | env MISE_INSTALL_PATH="$RISCV/bin/mise" MISE_VERSION="$MISE_VERSION" MISE_QUIET=1 sh
    echo "$MISE_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}mise successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}mise already up to date.${ENDC}"
fi
