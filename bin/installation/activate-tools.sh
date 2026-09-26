#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: Activate gcc and python virtual environment
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
fi

# Enable newer version of gcc for older distros (required for QEMU/Verilator)
if [ "$FAMILY" == rhel ] && (( RHEL_VERSION < 10 )); then
    if [ -e /opt/rh/gcc-toolset-13/enable ]; then
        source /opt/rh/gcc-toolset-13/enable
    else
        echo -e "${FAIL_COLOR}GCC toolset 13 not found. Please install it with wally-package-install.sh.${ENDC}"
        return 1
    fi
elif [ "$FAMILY" == suse ] && ((SUSE_VERSION < 160)); then
    if [ ! -e "$RISCV"/gcc-13/bin/gcc ]; then
        mkdir -p "$RISCV"/gcc-13/bin
        for f in gcc cpp g++ gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool lto-dump; do
            ln -vsf /usr/bin/$f-13 "$RISCV"/gcc-13/bin/$f
        done
    fi
    export PATH="$RISCV"/gcc-13/bin:$PATH
elif (( UBUNTU_VERSION == 20 )); then
    if [ ! -e "$RISCV"/gcc-10/bin/gcc ]; then
        mkdir -p "$RISCV"/gcc-10/bin
        for f in gcc cpp g++ gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool lto-dump; do
            ln -vsf /usr/bin/$f-10 "$RISCV"/gcc-10/bin/$f
        done
    fi
    export PATH="$RISCV"/gcc-10/bin:$PATH
elif (( UBUNTU_VERSION == 26 )); then
    if [ ! -e "$RISCV"/gnuinstall/bin/install ]; then
        mkdir -p "$RISCV"/gnuinstall/bin
        ln -vsf "$(which gnuinstall)" $RISCV/gnuinstall/bin/install
    fi
    export PATH="$RISCV"/gnuinstall/bin:$PATH
fi
