# setup.sh
# David_Harris@hmc.edu and kekim@hmc.edu 1 December 2021
# jcarlin@hmc.edu 2025
# Set up tools for cvw

# optionally have .bashrc or .bash_profile source this file with
#if [ -f ~/cvw/setup.sh ]; then
#    source ~/cvw/setup.sh
#fi

# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Colors for terminal output
WARNING_COLOR='\033[93m'
FAIL_COLOR='\033[91m'
ENDC='\033[0m' # Reset to default color

echo "Executing Wally setup.sh"

# Path to RISC-V Tools
if [ -d ~/riscv ]; then
    export RISCV=~/riscv
elif [ -d /opt/riscv ]; then
    export RISCV=/opt/riscv
else
    # set the $RISCV directory here and remove the subsequent two lines
    # export RISCV=
    echo -e "${FAIL_COLOR}\$RISCV directory not found. Checked /opt/riscv and ~/riscv. Edit setup.sh to point to your custom \$RISCV directory.${ENDC}"
    return 1
fi
echo \$RISCV set to "${RISCV}"

# Path to Wally repository
WALLY=$(dirname "${BASH_SOURCE[0]:-$0}")
WALLY=$(cd "$WALLY" && pwd)
export WALLY
echo \$WALLY set to "${WALLY}"
# utility functions in Wally repository
export PATH=$WALLY/bin:$PATH

# Verilator needs a larger core file size to simulate CORE-V Wally
ulimit -c 300000

# load site licenses and tool locations
if [ -e "${RISCV}"/site-setup.sh ]; then
    source "${RISCV}"/site-setup.sh
else
    echo -e "${FAIL_COLOR}site-setup.sh not found in \$RISCV directory. Rerun wally-toolchain-install.sh to automatically download it.${ENDC}"
    return 1
fi

if [ ! -e "${WALLY}/.git/hooks/pre-commit" ]; then
    pushd "${WALLY}" || return 1
    echo "Installing pre-commit hooks"
    uv run pre-commit install
    popd || return
fi

echo "setup done"
