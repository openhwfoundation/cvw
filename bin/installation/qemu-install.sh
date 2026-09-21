#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: QEMU installation script
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

QEMU_VERSION=v11.0.2 # Last release as of July 2, 2026

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# QEMU (https://www.qemu.org/docs/master/system/target-riscv.html)
# QEMU is an open source machine emulator and virtualizer capable of emulating RISC-V
section_header "Installing/Updating QEMU"
STATUS="qemu"
cd "$RISCV"
if check_tool_version $QEMU_VERSION; then
    git_checkout "qemu" "https://github.com/qemu/qemu" "$QEMU_VERSION"
    cd "$RISCV"/qemu
    # Create Python venv for QEMU dependencies; requires tomllib which is only available in Python 3.11+
    # Use uv managed Python to avoid issue with missing components of stdlib in some distros' Python builds.
    uv venv --managed-python --python 3.12
    uv pip install sphinx sphinx_rtd_theme pip setuptools
    QEMU_PYTHON="$RISCV/qemu/.venv/bin/python3"
    ./configure --target-list=riscv64-softmmu,riscv32-softmmu --prefix="$RISCV" --python=$QEMU_PYTHON
    make -j "${NUM_THREADS}" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    make install 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    if [ "$clean" = true ]; then
        cd "$RISCV"
        rm -rf qemu
    fi
    echo "$QEMU_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}QEMU successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}QEMU already up to date.${ENDC}"
fi
