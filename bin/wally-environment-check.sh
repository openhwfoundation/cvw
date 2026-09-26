#!/bin/bash
###########################################
## Get Linux distro information and check environment
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: 30 June 2024
## Modified: May 30 2025
##
## Purpose: Check for compatible Linux distribution and set variables accordingly
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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

### Colors ###
BOLD='\033[1m'
UNDERLINE='\033[4m'
SECTION_COLOR='\033[95m'$BOLD
OK_COLOR='\033[94m'
SUCCESS_COLOR='\033[92m'
WARNING_COLOR='\033[93m'
FAIL_COLOR='\033[91m'
ENDC='\033[0m' # Reset to default color

if [ -z "$WALLY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname "$dir")"
    export WALLY
fi

### Common functions and error handling ###
source "$WALLY"/bin/installation/wally-installation-helper-functions.sh
trap error ERR # run error handler on error
STATUS="setup" # keep track of what part of the installation is running for error messages


section_header "Checking System Requirements and Configuring Installation"

### Get distribution information ###
if [ -f /etc/os-release ]; then
    source /etc/os-release
else
    printf "${FAIL_COLOR}%s\n${ENDC}" "/etc/os-release file not found. Distribution unknown."
    PRETTY_NAME=UNKNOWN
fi

# Check for compatible distro
if [[ "$ID" == rhel || "$ID_LIKE" == *rhel* ]]; then
    export FAMILY=rhel
    if [ "$ID" != rhel ] && [ "$ID" != rocky ] && [ "$ID" != almalinux ]; then
        printf "${WARNING_COLOR}%s%s\n${ENDC}" "For Red Hat family distros, the Wally installation script has only been tested on RHEL, Rocky Linux," \
            " and AlmaLinux. Your distro is $PRETTY_NAME. The regular Red Hat install will be attempted, but there may be issues."
    fi
    export RHEL_VERSION="${VERSION_ID%%.*}" # Get major version number
    if (( RHEL_VERSION < 8 )); then
        printf "${FAIL_COLOR}%s\n${ENDC}" "The Wally installation script is only compatible with versions 8, 9, and 10 of RHEL, Rocky Linux, and AlmaLinux. You have version $VERSION. Please upgrade to a supported version."
        exit 1
    fi
    if (( RHEL_VERSION > 10 )); then
        printf "${WARNING_COLOR}%s\n${ENDC}" "The Wally installation script has only been tested with Red Hat family versions 8, 9, and 10. You have a newer version ($VERSION). The installation for Red Hat 10 will be attempted, but there may be issues."
    fi
elif [[ "$ID" == ubuntu || "$ID_LIKE" == *ubuntu* ]]; then
    export FAMILY=ubuntu
    if [ "$ID" != ubuntu ]; then
        printf "${WARNING_COLOR}%s%s\n${ENDC}" "For Ubuntu family distros, the Wally installation script is only tested on standard Ubuntu. Your distro " \
            "is $PRETTY_NAME. The regular Ubuntu install will be attempted, but there may be issues."
        # Ubuntu derivates may use different version numbers. Attempt to derive version from Ubuntu codename
        case "$UBUNTU_CODENAME" in
            resolute)
                export UBUNTU_VERSION=26
                ;;
            noble)
                export UBUNTU_VERSION=24
                ;;
            jammy)
                export UBUNTU_VERSION=22
                ;;
            focal)
                export UBUNTU_VERSION=20
                ;;
            *)
                printf "${FAIL_COLOR}%s\n${ENDC}" "Unable to determine which base Ubuntu version you are using."
                exit 1
                ;;
        esac
        echo "Detected Ubuntu derivative based on Ubuntu $UBUNTU_VERSION.04."
    else
        export UBUNTU_VERSION="${VERSION_ID%%.*}" # Major version
        UBUNTU_MINOR="${VERSION_ID#*.}"
    fi
    if (( UBUNTU_VERSION < 20 )); then
        printf "${FAIL_COLOR}%s\n${ENDC}" "The Wally installation script has only been tested with Ubuntu versions 20.04 LTS, 22.04 LTS, 24.04 LTS, and 26.04 LTS. You have version $VERSION. Please upgrade to a supported version of Ubuntu."
        exit 1
    fi
    # Warn if non LTS version or newer version
    if ! [[ "$UBUNTU_MINOR" == 04 && "$UBUNTU_VERSION" =~ ^(20|22|24|26)$ ]]; then
        printf "${WARNING_COLOR}%s\n${ENDC}" "The Wally installation script has only been tested with Ubuntu versions 20.04 LTS, 22.04 LTS, 24.04 LTS, and 26.04 LTS. You have version $VERSION. The installation for the preceding Ubuntu LTS release will be attempted, but there may be issues."
    fi
elif [[ "$ID" == debian || "$ID_LIKE" == *debian* ]]; then
    export FAMILY=debian
    if [ "$ID" != debian ]; then
        printf "${WARNING_COLOR}%s%s\n${ENDC}" "For Debian family distros, the Wally installation script has only been tested on standard Debian (and Ubuntu). Your distro " \
            "is $PRETTY_NAME. The regular Debian install will be attempted, but there may be issues."
    fi
    export DEBIAN_VERSION="$VERSION_ID"
    if (( DEBIAN_VERSION < 11 )); then
        printf "${FAIL_COLOR}%s\n${ENDC}" "The Wally installation script has only been tested with Debian versions 11, 12, and 13. You have version $VERSION. Please upgrade to a supported version of Debian."
        exit 1
    fi
    if (( DEBIAN_VERSION > 13 )); then
        printf "${WARNING_COLOR}%s\n${ENDC}" "The Wally installation script has only been tested with Debian versions 11, 12, and 13. You have a newer version ($VERSION). The installation for Debian 13 will be attempted, but there may be issues."
    fi
elif [[ "$ID" == opensuse-leap || "$ID" == sles || "$ID_LIKE" == *suse* ]]; then
    export FAMILY=suse
    if [[ "$ID" != opensuse-leap && "$ID" != sles  ]]; then
        printf "${WARNING_COLOR}%s%s\n${ENDC}" "For SUSE family distros, the Wally installation script has only been tested on OpenSUSE Leap and SLES. Your distro " \
            "is $PRETTY_NAME. The regular SUSE install will be attempted, but there may be issues. If you are using OpenSUSE Tumbleweed, the version check will fail."
    fi
    export SUSE_VERSION="${VERSION_ID//.}"
    if (( SUSE_VERSION < 156 )); then
        printf "${FAIL_COLOR}%s\n${ENDC}" "The Wally installation script has only been tested with SUSE versions 15.6 and 16.0. You have version $VERSION. Please upgrade to a supported version of SUSE."
        exit 1
    fi
    if (( SUSE_VERSION > 160 )); then
        printf "${WARNING_COLOR}%s\n${ENDC}" "The Wally installation script has only been tested with SUSE versions 15.6 and 16.0. You have a newer version ($VERSION). The installation for SUSE 16.0 will be attempted, but there may be issues."
    fi
else
    printf "${FAIL_COLOR}%s%s%s\n${ENDC}" "The Wally installation script is currently only compatible with Ubuntu, Debian, SUSE, and Red Hat family " \
        "(RHEL, Rocky Linux, or AlmaLinux) distros. Your detected distro is $PRETTY_NAME. You may try manually running the " \
        "commands in this script, but it is likely that some will need to be altered."
    exit 1
fi

# wget retry on host error flag not available with older wget on RHEL 8
if (( RHEL_VERSION != 8 )); then
    retry_on_host_error="--retry-on-host-error"
fi


### Configure installation ###
# Check flags
clean=false
no_buildroot=false
packages_only=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--clean) clean=true ;;
        --no-buildroot) no_buildroot=true ;;
        --packages-only) packages_only=true;;
        -h|--help)
            echo -e "Usage: $0 [\$RISCV] [options]"
            echo -e "${BOLD}Options:${ENDC}"
            echo -e "  -c, --clean          Remove build directories after installation"
            echo -e "  --no-buildroot       Skip installing Buildroot and Linux testvectors"
            echo -e "  \$RISCV              Directory to install RISC-V tools (default: /opt/riscv as root, $HOME/riscv otherwise)"
            exit 0 ;;
        *) RISCV="$1" ;;
    esac
    shift
done

# Check if root
ROOT=$( [ "${EUID:=$(id -u)}" == 0 ] && echo true || echo false);

### Print system information ###
echo -e "${OK_COLOR}${UNDERLINE}Detected information${ENDC}"
echo "Distribution: $PRETTY_NAME"
echo "Version: $VERSION"
echo "Running as root: $ROOT"

if [ $packages_only != true ]; then
    # Set installation directory based on execution privileges
    # If the script is run as root, the default installation path is /opt/riscv
    # If the script is run as a user, the default installation path is ~/riscv
    # The installation path can be overridden with a positional argument passed to the script.
    if [ "$ROOT" == true ]; then
        export RISCV="${RISCV:-/opt/riscv}"
    else
        export RISCV="${RISCV:-$HOME/riscv}"
    fi

    # Set environment variables
    export PATH=$RISCV/bin:$PATH:/usr/bin
    export PKG_CONFIG_PATH=$RISCV/lib64/pkgconfig:$RISCV/lib/pkgconfig:$RISCV/share/pkgconfig:$RISCV/lib/x86_64-linux-gnu/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}

    # Check for incompatible PATH environment variable before proceeding with installation
    if [[ ":$PATH:" == *::* || ":$PATH:" == *:.:* ]]; then
        echo -e "${FAIL_COLOR}Error: You seem to have the current working directory in your \$PATH environment variable."
        echo -e "This won't work. Please update your \$PATH and try again.${ENDC}"
        exit 1
    fi

    # Increasing NUM_THREADS will speed up parallel compilation of the tools
    NUM_THREADS=$(nproc --ignore 1) # One less than the total number of threads

    # Check available memory
    total_mem=$(grep MemTotal < /proc/meminfo | awk '{print $2}')
    total_mem_gb=$((total_mem / 1024 / 1024))

    # Reduce number of threads for systems with less than 8 GB of memory
    if ((total_mem < 8400000 )) ; then
        NUM_THREADS=1
        echo -e "${WARNING_COLOR}Detected less than or equal to 8 GB of memory. Using a single thread for compiling tools. This may take a while.${ENDC}"
    fi

    # Create installation directory
    mkdir -p "$RISCV"/logs
    mkdir -p "$RISCV"/versions

    # Print more system information
    echo "Installation path: $RISCV"
    echo "Number of cores: $(nproc)"
    echo "Total memory: $total_mem_gb GB"
    echo "Using $NUM_THREADS thread(s) for compilation"
fi
