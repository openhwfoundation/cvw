# site-setup.csh
# System Admin should install this into $RISCV/site-setup.csh
# It is automatically placed in the $RISCV directory by wally-toolchain-install.sh
# $RISCV is typically /opt/riscv or ~/riscv
# System Admin must update the licenses and paths for localization.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# License servers and commercial CAD tool paths
# Must edit these based on your local environment.  Ask your sysadmin.
setenv MGLS_LICENSE_FILE 27002@zircon.eng.hmc.edu                         # Change this to your Siemens license server
setenv SNPSLMD_LICENSE_FILE 27020@zircon.eng.hmc.edu                      # Change this to your Synopsys license server
setenv QUESTAPATH /cad/mentor/QUESTA/bin                                  # Change this for your path to Questa
setenv DCPATH /cad/synopsys/SYN/bin                                       # Change this for your path to Design Compiler
setenv VCSPATH /cad/synopsys/VCS/bin                                      # Change this for your path to Synopsys VCS
setenv BREKER_HOME /cad/breker/TREK                                       # Change this for your path to Breker Trek
setenv SPYGLASS_HOME /cad/synopsys/SPYGLASS_HOME                          # Change this for your path to Synopsys Spyglass
setenv IMPERAS_HOME /cad/imperas/IMPERAS_DV                               # Change this for your path to Synopsys ImperasDV

# Tools
# Questa and Synopsys
extend PATH $QUESTAPATH
extend PATH $DCPATH
extend PATH $VCSPATH
extend PATH $SPYGLASS_HOME/bin
# Synopsys Spyglass
setenv SNPSLMD_QUEUE 1

# GCC
if ( ! $?LD_LIBRARY_PATH ) then
    setenv LD_LIBRARY_PATH $RISCV/riscv64-unknown-elf/lib
else
    extend LD_LIBRARY_PATH $RISCV/riscv64-unknown-elf/lib
endif

# RISC-V Tools
extend LD_LIBRARY_PATH $RISCV/lib
extend LD_LIBRARY_PATH $RISCV/lib64
extend LD_LIBRARY_PATH $RISCV/lib/x86_64-linux-gnu/
extend PATH $RISCV/bin

# environment variables needed for RISCV-DV
setenv RISCV_GCC `which riscv64-unknown-elf-gcc`                  # Copy this as it is
setenv RISCV_OBJCOPY `which riscv64-unknown-elf-objcopy`          # Copy this as it is
setenv SPIKE_PATH $RISCV/bin                                      # Change this for your path to riscv-isa-sim (spike)

# Imperas DV setup
if ($?IMPERAS_HOME) then
    setenv IMPERAS_PERSONALITY CPUMAN_DV_ASYNC
    setenv ROOTDIR ~/
    source ${IMPERAS_HOME}/bin/setup.sh
    setupImperas ${IMPERAS_HOME}
endif

# Use newer gcc version for older distros
if ( -e $RISCV/gcc-13 ) then
    prepend PATH $RISCV/gcc-13/bin # SUSE Family
elseif ( -e $RISCV/gcc-10 ) then
    prepend PATH $RISCV/gcc-10/bin # Ubuntu 20.04 LTS
endif
