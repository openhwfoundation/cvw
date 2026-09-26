#!/bin/bash

# site-setup.sh
# David_Harris@hmc.edu and kekim@hmc.edu 1 December 2021
# jcarlin@hmc.edu 2025
# System Admin should install this into $RISCV/site-setup.sh
# It is automatically placed in the $RISCV directory by wally-toolchain-install.sh
# $RISCV is typically /opt/riscv or ~/riscv
# System Admin must update the licenses and paths for localization.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Colors for terminal output
FAIL_COLOR='\033[91m'
ENDC='\033[0m' # Reset to default color

# license servers and commercial CAD tool paths
# Must edit these based on your local environment.
export MGLS_LICENSE_FILE=27002@zircon.eng.hmc.edu                   # Change this to your Siemens license server for Questa
export SNPSLMD_LICENSE_FILE=27020@zircon.eng.hmc.edu                # Change this to your Synopsys license server
export IMPERASD_LICENSE_FILE=27020@zircon.eng.hmc.edu               # Change this to your Imperas license server
export BREKER_LICENSE_FILE=1819@zircon.eng.hmc.edu                  # Change this to your Breker license server
export QUESTA_HOME=/cad/mentor/QUESTA                               # Change this for your path to Questa, excluding bin
export DC_HOME=/cad/synopsys/SYN                                    # Change this for your path to Synopsys DC, excluding bin
export VCS_HOME=/cad/synopsys/VCS                                   # Change this for your path to Synopsys VCS, excluding bin
export BREKER_HOME=/cad/breker/TREK                                 # Change this for your path to Breker Trek
export SPYGLASS_HOME=/cad/synopsys/SPYGLASS_HOME                    # Change this for your path to Synopsys Spyglass
export IMPERAS_HOME=/cad/imperas/IMPERAS_DV                         # Change this for your path to Synopsys ImperasDV

# Tools
# Questa and Synopsys
export PATH=$QUESTA_HOME/bin:$DC_HOME/bin:$VCS_HOME/bin:$SPYGLASS_HOME/bin:$PATH
# Synopsys Spyglass
export SNPSLMD_QUEUE=1

# Environmental variables for SoC
export SYN_pdk=/proj/models/tsmc28/libraries/28nmtsmc/tcbn28hpcplusbwp30p140_190a/
#export osupdk=/import/yukari1/pdk/TSMC/28/CMOS/HPC+/stclib/9-track/tcbn28hpcplusbwp30p140-set/tcbn28hpcplusbwp30p140_190a_FE/
export SYN_TLU=/home/jstine/TLU+
#export OSUTLU=/import/yukari1/pdk/TSMC/TLU+
export SYN_MW=/home/jstine/MW
#export OSUMW=/import/yukari1/pdk/TSMC/MW
export SYN_memory=/home/jstine/WallyMem/rv64gc/
#export osumemory=/import/yukari1/pdk/TSMC/WallyMem/rv64gc/

# GCC
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}$RISCV/riscv64-unknown-elf/lib
# RISC-V Tools
export LD_LIBRARY_PATH=$RISCV/lib:$RISCV/lib64:$LD_LIBRARY_PATH:$RISCV/lib/x86_64-linux-gnu/
export PATH=$PATH:$RISCV/bin

# Environment variables needed for RISCV-DV
export RISCV_GCC=$(which riscv64-unknown-elf-gcc)
export RISCV_OBJCOPY=$(which riscv64-unknown-elf-objcopy)
export SPIKE_PATH=$RISCV/bin

# Imperas DV setup
if [ -e "$IMPERAS_HOME" ]; then
    export IMPERAS_PERSONALITY=CPUMAN_DV_ASYNC
    source "${IMPERAS_HOME}"/bin/setup.sh &> /dev/null || {
        echo -e "${FAIL_COLOR}ImperasDV setup failed${ENDC}"
        return 1
    }
    setupImperas "${IMPERAS_HOME}" &> /dev/null || {
        echo -e "${FAIL_COLOR}setupImperas failed${ENDC}"
        return 1
    }
fi

# Use newer gcc version for older distros
if [ -e /opt/rh/gcc-toolset-13/enable ]; then
    source /opt/rh/gcc-toolset-13/enable # Red Hat Family 8 and 9
elif [ -e "$RISCV"/gcc-13 ]; then
    export PATH=$RISCV/gcc-13/bin:$PATH  # SUSE Family
elif [ -e "$RISCV"/gcc-10 ]; then
    export PATH=$RISCV/gcc-10/bin:$PATH  # Ubuntu 20.04 LTS
fi
