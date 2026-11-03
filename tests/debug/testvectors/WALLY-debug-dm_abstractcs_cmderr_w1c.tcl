######################################################################
# WALLY-debug-dm_abstractcs_cmderr_w1c
# Rule dm_abstractcs_cmderr_w1c: "The bits in this field remain set
# until they are cleared by writing 1 to them."
#
# cmderr bits clear only where 1 is written: with cmderr=2, writing 0
# keeps it and writing 0x200 (bit 1) clears it; with cmderr=3, writing
# 0x100 (bit 0) leaves 2, then 0x200 clears it.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

halt_hart
cmd_wait [access_reg_cmd [gpr 5] 4 0]
check_cmderr
dmi_wr $DM_ABSTRACTCS 0
dmi_rd $DM_ABSTRACTCS
check_cmderr
dmi_wr $DM_ABSTRACTCS 0x200
dmi_rd $DM_ABSTRACTCS
check_cmderr
clear_cmderr
cmd_wait [access_reg_cmd 0x600 $XSZ 0]
check_cmderr
dmi_wr $DM_ABSTRACTCS 0x100
dmi_rd $DM_ABSTRACTCS
check_cmderr
dmi_wr $DM_ABSTRACTCS 0x200
dmi_rd $DM_ABSTRACTCS
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
