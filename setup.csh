#!/bin/csh

# setup.csh
# james.stine@okstate.edu 18 February 2023

echo "Executing Wally setup.csh"


# Extend alias which makes extending PATH much easier.
alias extend 'if (-d \!:2) if ("$\!:1" \!~ *"\!:2"*) setenv \!:1 ${\!:1}:\!:2;echo Added \!:2 to \!:1'
alias prepend 'if (-d \!:2) if ("$\!:1" \!~ *"\!:2"*) setenv \!:1 "\!:2":${\!:1};echo Added \!:2 to \!:1'

# Path to RISC-V Tools
if ( -d /opt/riscv ) then
    setenv RISCV /opt/riscv
else if ( -d ~/riscv ) then
    setenv RISCV ~/riscv
else
    # set the $RISCV directory here and remove the subsequent two lines
    # setenv RISCV
    echo "\$RISCV directory not found. Checked /opt/riscv and ~/riscv. Edit setup.csh to point to your custom \$RISCV directory."
    exit 1;
endif
echo \$RISCV set to "${RISCV}"

# Path to Wally repository
setenv WALLY $PWD
echo '$WALLY set to ' ${WALLY}
# utility functions in Wally repository
extend PATH $WALLY/bin

# Verilator needs a larger stack to simulate CORE-V Wally
limit stacksize unlimited

# load site licenses and tool locations
if ( -e "${RISCV}"/site-setup.csh ) then
    source $RISCV/site-setup.csh
else
    echo "site-setup.csh not found in \$RISCV directory. Rerun wally-toolchain-install.sh to automatically download it."
endif

echo "setup done"
