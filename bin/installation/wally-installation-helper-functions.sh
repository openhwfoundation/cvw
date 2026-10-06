#!/bin/bash
###########################################
## Installation helper functions.
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: May 30 2025
## Modified:
##
## Purpose: Common functions for toolchain installation scripts
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https://solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################

set -e # break on error

## Helper functions
# Error handler
error() {
    echo -e "${FAIL_COLOR}Error: $STATUS installation failed"
    echo -e "Error on line ${BASH_LINENO[0]} with command $BASH_COMMAND${ENDC}"
    if [ -e "$RISCV/logs/$STATUS.log" ]; then
        echo -e "Please check the log in $RISCV/logs/$STATUS.log for more information."
    fi
    exit 1
}

# Check if the specified version of a tool is installed
# $1: required version
# Tool inferred from $STATUS variable
check_tool_version() {
    local required_version="$1"
    local version_file="$RISCV/versions/$STATUS.version"
    if [ -f "$version_file" ] && [ "$(cat "$version_file")" = "$required_version" ]
    then
        return 1  # Tool is up-to-date
    else
        return 0  # Tool needs installation or update
    fi
}

# Checkout specified version of a git repository
# $1: repo name
# $2: repo url to clone from
# $3: version to checkout (commit hash or tag)
git_checkout() {
    local repo=$1
    local url=$2
    local version=$3

    # Clone repo if it doesn't exist
    if [[ ! -e $repo ]]; then
        for ((i=1; i<=5; i++)); do
            git clone "$url" "$repo" && break
            echo -e "${WARNING_COLOR}Failed to clone $repo. Retrying.${ENDC}"
            rm -rf "$repo"
            sleep $i
        done
        if [[ ! -e $repo ]]; then
            echo -e "${ERROR_COLOR}Failed to clone $repo after 5 attempts. Exiting.${ENDC}"
            exit 1
        fi
    fi

    # Update the repository
    cd "$repo"
    git fetch --all

    # Checkout the specified version
    git reset --hard "$version"
    git clean -fdx && git submodule update
}

# Log output to a file and only print lines with keywords
logger() {
    local log_file="$RISCV/logs/$STATUS.log"
    local keyword_pattern="(\bwarning|\berror|\bfail|\bsuccess|\bstamp|\bdoesn't work)"
    local exclude_pattern="(_warning|warning_|_error|error_|-warning|warning-|-error|error-|Werror|error\.o|warning flags)"

    cat < /dev/stdin | tee -a "$log_file" | \
    (grep -iE --color=never "$keyword_pattern" || true) | \
    (grep -viE --color=never "$exclude_pattern" || true)
}

# Print section header
section_header() {
    if tput cols > /dev/null 2>&1; then
        printf "${SECTION_COLOR}%$(tput cols)s\n" | tr ' ' '#'
        printf "%$(tput cols)s\n" | tr ' ' '#'
        printf "%s\n" "$1"
        printf "%$(tput cols)s\n" | tr ' ' '#'
        printf "%$(tput cols)s${ENDC}\n" | tr ' ' '#'
    else
        printf "${SECTION_COLOR}%s\n${ENDC}" "$1"
    fi
}
