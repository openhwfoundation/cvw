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

# Activate mise, which provides cvw's tools (uv and prek; see .mise.toml), installing any this user lacks.
# cvw's tools also go on PATH directly, so the scripts in $WALLY/bin find uv outside the cvw tree too.
if command -v mise > /dev/null; then
    export MISE_TRUSTED_CONFIG_PATHS="$WALLY${MISE_TRUSTED_CONFIG_PATHS:+:$MISE_TRUSTED_CONFIG_PATHS}"
    mise install --cd "$WALLY" --quiet --yes
    if [ -n "$ZSH_VERSION" ]; then
        eval "$(mise activate zsh)"
    else
        eval "$(mise activate bash)"
    fi
    eval "$(mise env --cd "$WALLY" --shell bash)"
else
    echo -e "${FAIL_COLOR}mise not found in \$RISCV/bin. Rerun wally-tool-chain-install.sh to install it.${ENDC}"
    return 1
fi

# Install the pre-commit hook unless there is one already (the hooks directory is shared by every worktree)
hook=$(git -C "${WALLY}" rev-parse --path-format=absolute --git-path hooks/pre-commit 2> /dev/null)
if [ -n "$hook" ] && [ ! -e "$hook" ]; then
    echo "Installing pre-commit hooks"
    (cd "${WALLY}" && prek install) || return 1
fi

echo "setup done"
