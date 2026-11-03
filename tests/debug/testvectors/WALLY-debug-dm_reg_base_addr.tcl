######################################################################
# WALLY-debug-dm_reg_base_addr
# Rule dm_reg_base_addr: "Each DM has a base address (which is 0 for
# the first DM). The register addresses below are offsets from this
# base address."
#
# Wally's DM is the first DM, at base 0: its registers answer at the
# table offsets (dmcontrol.dmactive at 0x10, abstractcs.datacount at
# 0x16, and nextdm at 0x1d is 0).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL 0x1
dmi_rd $DM_ABSTRACTCS
tv_check $DM_ABSTRACTCS 0xf
dmi_rd $DM_NEXTDM
tv_check $DM_NEXTDM 0xffffffff 0
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
