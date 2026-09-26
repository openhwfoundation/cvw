#!/bin/bash
###########################################
## Package installation
##
## Written: Jordan Carlin, jcarlin@hmc.edu
## Created: 30 June 2024
## Modified: May 30 2025
## Modified: 24 Jan 2026, James Stine james.stine@okstate.edu
##
## Purpose: Package manager installation for open source tool chain installation script
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

STATUS="system_packages"

# If run standalone, check environment. Otherwise, use info from main install script
if [ -z "$FAMILY" ]; then
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WALLY="$(dirname "$dir")"
    export WALLY
    source "${dir}"/wally-environment-check.sh "--packages-only"
fi


# Packages are grouped by which tool requires them. If multiple tools need a package, it is included in each tool's list.
# Packages that are constant across distros
GENERAL_PACKAGES+=(rsync git wget tar unzip gzip bzip2 gcc make dialog mutt) # TODO: check what needs dialog
GNU_PACKAGES+=(autoconf automake gawk bison flex texinfo gperf libtool patchutils bc)
SAIL_PACKAGES+=(cmake)
VERILATOR_PACKAGES+=(autoconf flex bison help2man perl ccache numactl gtkwave) # gtkwave is not needed for verilator, but useful for viewing waveforms
BUILDROOT_PACKAGES+=(patchutils perl cpio bc)

# OPENOCD packages are distro-specific
# OpenOCD build dependencies (Jim Tcl + FTDI + USB)
case "$FAMILY" in
  rhel)
    OPENOCD_PACKAGES+=(jimtcl jimtcl-devel libftdi-devel libusb1-devel pkgconf-pkg-config)
    ;;
  ubuntu|debian)
    OPENOCD_PACKAGES+=(libjim-dev libftdi1-dev libusb-1.0-0-dev pkg-config)
    ;;
  suse)
    OPENOCD_PACKAGES+=(jimtcl jimtcl-devel libftdi-devel libusb-1_0-devel pkg-config)
    ;;
esac

# Distro specific packages and package manager
case "$FAMILY" in
    rhel)
        PYTHON_VERSION=python3.12
        PACKAGE_MANAGER="dnf -y"
        UPDATE_COMMAND="$PACKAGE_MANAGER update"
        GENERAL_PACKAGES+=(which "$PYTHON_VERSION" "$PYTHON_VERSION"-pip pkgconf-pkg-config gcc-c++)
        GNU_PACKAGES+=(libmpc-devel mpfr-devel gmp-devel zlib-devel expat-devel glib2-devel libslirp-devel)
        QEMU_PACKAGES+=(glib2-devel libfdt-devel pixman-devel zlib-devel ninja-build)
        SPIKE_PACKAGES+=(dtc) # compiling Spike with boost fails on RHEL
        WHISPER_PACKAGES+=(libstdc++-static) # Whisper links with -static-libstdc++
        SAIL_PACKAGES+=(ninja-build gmp-devel)
        VERILATOR_PACKAGES+=(zlib-devel gperftools-devel mold)
        BUILDROOT_PACKAGES+=(ncurses ncurses-base ncurses-libs ncurses-devel gcc-gfortran) # gcc-gfortran is only needed for compiling spec benchmarks on buildroot linux
        # Extra packages not available in rhel8, nice for Verilator
        if (( RHEL_VERSION >= 9 )); then
            VERILATOR_PACKAGES+=(perl-doc)
        fi
        if (( RHEL_VERSION < 10)); then
            GENERAL_PACKAGES+=(ssmtp) # ssmtp is no longer available in RHEL 10 EPEL
            GENERAL_PACKAGES+=(gcc-toolset-13) # A newer version of gcc is required for qemu
        fi
        ;;
    ubuntu | debian)
        if (( UBUNTU_VERSION >= 26 )); then
            PYTHON_VERSION=python3.14
        elif (( UBUNTU_VERSION >= 24 )); then
            PYTHON_VERSION=python3.12
        elif (( UBUNTU_VERSION >= 22 )); then
            PYTHON_VERSION=python3.11
        elif (( UBUNTU_VERSION >= 20 )); then
            PYTHON_VERSION=python3.9
            GENERAL_PACKAGES+=(gcc-10 g++-10 cpp-10) # Newer version of gcc needed for Verilator
        elif (( DEBIAN_VERSION >= 13 )); then
            PYTHON_VERSION=python3.13
        elif (( DEBIAN_VERSION >= 12 )); then
            PYTHON_VERSION=python3.11
        elif (( DEBIAN_VERSION >= 11 )); then
            PYTHON_VERSION=python3.9
        fi
        # Mold not available in older distros for Verilator, will download binary instead
        if (( UBUNTU_VERSION != 20 && DEBIAN_VERSION != 11 )); then
            VERILATOR_PACKAGES+=(mold)
        fi
        PACKAGE_MANAGER="DEBIAN_FRONTEND=noninteractive apt-get -y"
        UPDATE_COMMAND="$PACKAGE_MANAGER update && $PACKAGE_MANAGER upgrade --with-new-pkgs"
        GENERAL_PACKAGES+=(curl "$PYTHON_VERSION" python3-pip "$PYTHON_VERSION"-venv pkg-config build-essential g++ ssmtp)
        GNU_PACKAGES+=(autotools-dev libmpc-dev libmpfr-dev libgmp-dev zlib1g-dev libexpat1-dev libglib2.0-dev libslirp-dev)
        QEMU_PACKAGES+=(libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build)
        SPIKE_PACKAGES+=(device-tree-compiler libboost-regex-dev libboost-system-dev)
        SAIL_PACKAGES+=(ninja-build libgmp-dev)
        VERILATOR_PACKAGES+=(libfl2 libfl-dev zlib1g-dev libunwind-dev libgoogle-perftools-dev perl-doc)
        BUILDROOT_PACKAGES+=(ncurses-base ncurses-bin libncurses-dev gfortran) # gfortran is only needed for compiling spec benchmarks on buildroot linux
        VIVADO_PACKAGES+=(libncurses*) # Vivado hangs on the third stage of installation without this
        ;;
    suse)
        if ((SUSE_VERSION >= 160)); then
            PYTHON_VERSION=python3.13
            PYTHON_VERSION_PACKAGE=python313
        elif ((SUSE_VERSION >= 156)); then
            PYTHON_VERSION=python3.12
            PYTHON_VERSION_PACKAGE=python312
        fi

        PACKAGE_MANAGER="zypper -n"
        UPDATE_COMMAND="$PACKAGE_MANAGER update"
        GENERAL_PACKAGES+=(which curl "$PYTHON_VERSION_PACKAGE" "$PYTHON_VERSION_PACKAGE"-pip pkg-config gcc-c++)
        GNU_PACKAGES+=(mpc-devel mpfr-devel gmp-devel zlib-devel libexpat-devel glib2-devel libslirp-devel)
        QEMU_PACKAGES+=(glib2-devel libfdt-devel libpixman-1-0-devel zlib-devel ninja)
        SPIKE_PACKAGES+=(dtc)
        SAIL_PACKAGES+=(ninja gmp-devel)
        VERILATOR_PACKAGES+=(libfl2 libfl-devel zlib-devel gperftools-devel perl-doc)
        BUILDROOT_PACKAGES+=(ncurses-utils ncurses-devel gcc-fortran) # gcc-fortran is only needed for compiling spec benchmarks on buildroot linux

        if ((SUSE_VERSION >= 160)); then
            SPIKE_PACKAGES+=(libboost_regex1_86_0-devel libboost_system1_86_0-devel)
            VERILATOR_PACKAGES+=(mold)
        elif ((SUSE_VERSION >= 156)); then
            SPIKE_PACKAGES+=(libboost_regex1_75_0-devel libboost_system1_75_0-devel)
            BUILDROOT_PACKAGES+=(ncurses5-devel) # ncurses5 is no longer packaged in SUSE 16
            GENERAL_PACKAGES+=(gcc13 gcc13-c++ cpp13) # Newer version of gcc needed for many tools. Default is gcc7
        fi
        ;;
esac


# Check if required packages are installed or install/update them depending on passed flag.
if [ "${1}" == "--check" ]; then
    section_header "Checking Dependencies from Package Manager"
    if [[ "$FAMILY" == rhel || "$FAMILY" == suse ]]; then
        for pack in "${GENERAL_PACKAGES[@]}" "${GNU_PACKAGES[@]}" "${QEMU_PACKAGES[@]}" "${SPIKE_PACKAGES[@]}" "${WHISPER_PACKAGES[@]}" "${SAIL_PACKAGES[@]}" "${VERILATOR_PACKAGES[@]}" "${BUILDROOT_PACKAGES[@]}" "${OPENOCD_PACKAGES[@]}"; do
            rpm -q "$pack" > /dev/null || (echo -e "${FAIL_COLOR}Missing packages detected (${WARNING_COLOR}$pack${FAIL_COLOR}). Run as root to auto-install or run wally-package-install.sh first.${ENDC}" && exit 1)
        done
    elif [[ "$FAMILY" == ubuntu || "$FAMILY" == debian ]]; then
        for pack in "${GENERAL_PACKAGES[@]}" "${GNU_PACKAGES[@]}" "${QEMU_PACKAGES[@]}" "${SPIKE_PACKAGES[@]}" "${WHISPER_PACKAGES[@]}" "${SAIL_PACKAGES[@]}" "${VERILATOR_PACKAGES[@]}" "${BUILDROOT_PACKAGES[@]}" "${OPENOCD_PACKAGES[@]}"; do
            dpkg -l "$pack" | grep "ii" > /dev/null || (echo -e "${FAIL_COLOR}Missing packages detected (${WARNING_COLOR}$pack${FAIL_COLOR}). Run as root to auto-install or run wally-package-install.sh first." && exit 1)
        done
    fi
    echo -e "${OK_COLOR}All required packages detected.${ENDC}"
else
    # Check if root, otherwise exit with error message
    [ "$ROOT" == false ] && echo -e "\n${FAIL_COLOR}Must be run as root${ENDC}" && exit 1

    section_header "Installing/Updating Dependencies from Package Manager"
    # Enable extra repos necessary for rhel
    if [ "$FAMILY" == rhel ]; then
        dnf install -y dnf-plugins-core
        dnf group install -y "Development Tools"
        if [ "$ID" == rhel ]; then
            subscription-manager repos --enable "codeready-builder-for-rhel-$RHEL_VERSION-$(arch)-rpms"
            dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$RHEL_VERSION.noarch.rpm"
        else # RHEL clone
            if (( RHEL_VERSION == 8 )); then
                dnf config-manager -y --set-enabled powertools
            else # Version >= 9
                dnf config-manager -y --set-enabled crb
            fi
            dnf install -y epel-release
        fi
    fi

    # Update and Upgrade tools
    eval "$UPDATE_COMMAND"

    # OpenSUSE 15.6 has incompatible ncurses packages with the base installation
    # See: https://bugzilla.suse.com/show_bug.cgi?id=1266957 closed as WONTFIX
    if [ "$FAMILY" == suse ] && ((SUSE_VERSION == 156)); then
        zypper -n install --allow-downgrade ncurses-devel ncurses-utils ncurses5-devel
    fi

    # Install packages listed above using appropriate package manager
    eval $PACKAGE_MANAGER install "${GENERAL_PACKAGES[@]}" "${GNU_PACKAGES[@]}" "${QEMU_PACKAGES[@]}" "${SPIKE_PACKAGES[@]}" "${WHISPER_PACKAGES[@]}" "${SAIL_PACKAGES[@]}" "${VERILATOR_PACKAGES[@]}" "${BUILDROOT_PACKAGES[@]}" "${OPENOCD_PACKAGES[@]}" "${VIVADO_PACKAGES[@]}"

    # Post install steps
    # Vivado looks for ncurses5 libraries, but Ubuntu 24.04 only has ncurses6
    # Create symbolic links to the ncurses6 libraries to fool Vivado
    if (( UBUNTU_VERSION >= 24 )); then
        lib_dir=$(gcc -dumpmachine)
        ln -vsf /lib/"$lib_dir"/libncurses.so.6 /lib/"$lib_dir"/libncurses.so.5
        ln -vsf /lib/"$lib_dir"/libtinfo.so.6 /lib/"$lib_dir"/libntinfo.so.5
    fi

    echo -e "${SUCCESS_COLOR}Packages successfully installed.${ENDC}"
fi
