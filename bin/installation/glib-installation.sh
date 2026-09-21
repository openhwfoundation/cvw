#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: glib installation script
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

GLIB_VERSION=2.86.3

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# Newer version of glib required for QEMU.
section_header "Installing glib"
STATUS="glib"
cd "$RISCV"
if [ ! -e "$RISCV"/include/glib-2.0 ]; then
    wget -nv --retry-connrefused $retry_on_host_error --output-document=glib.tar.xz https://download.gnome.org/sources/glib/${GLIB_VERSION%.*}/glib-$GLIB_VERSION.tar.xz
    tar -xJf glib.tar.xz
    rm -f glib.tar.xz
    cd glib-$GLIB_VERSION
    uvx meson setup _build --prefix="$RISCV"
    uvx meson compile -C _build -j "${NUM_THREADS}" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    uvx meson install -C _build 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    cd "$RISCV"
    rm -rf glib-$GLIB_VERSION
    echo -e "${SUCCESS_COLOR}glib successfully installed!${ENDC}"
else
    echo -e "${OK_COLOR}glib already installed.${ENDC}"
fi
