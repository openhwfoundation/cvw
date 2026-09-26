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
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the "License"); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https:##solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
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
