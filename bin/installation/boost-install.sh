#!/bin/bash
###########################################
## Tool chain install script.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: March 22 2026
## Modified:
##
## Purpose: Boost library installation script
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

BOOST_VERSION=1.90.0 # Latest release as of March 22, 2026

set -e # break on error
# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname $(dirname "$dir"))"
    export WALLY
    source "${dir}"/../wally-environment-check.sh
fi

# Boost (https://www.boost.org/)
# The Boost C++ library is required by Whisper. Version 1.75 or higher compiled with C++20 is needed.
section_header "Installing/Updating Boost"
STATUS="boost"
cd "$RISCV"
if check_tool_version $BOOST_VERSION; then
    BOOST_VERSION_UNDERSCORE="${BOOST_VERSION//./_}"
    wget -nv --retry-connrefused $retry_on_host_error --output-document=boost.tar.gz \
        "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_UNDERSCORE}.tar.gz"
    tar xzf boost.tar.gz
    rm -f boost.tar.gz
    cd "boost_${BOOST_VERSION_UNDERSCORE}"
    ./bootstrap.sh --prefix="$RISCV" 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    ./b2 --without-mpi -j"${NUM_THREADS}" cxxflags="-std=c++20" install 2>&1 | logger; [ "${PIPESTATUS[0]}" == 0 ]
    cd "$RISCV"
    if [ "$clean" = true ]; then
        rm -rf "boost_${BOOST_VERSION_UNDERSCORE}"
    fi
    echo "$BOOST_VERSION" > "$RISCV"/versions/$STATUS.version # Record installed version
    echo -e "${SUCCESS_COLOR}Boost successfully installed/updated!${ENDC}"
else
    echo -e "${SUCCESS_COLOR}Boost already up to date.${ENDC}"
fi
