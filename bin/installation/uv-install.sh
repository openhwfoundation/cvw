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
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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

UV_VERSION=0.11.0 # Latest version as of March 23, 2026

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
