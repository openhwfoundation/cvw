######################################################################
# WALLY-debug-dm_abstractcs_cmderr_w1c
# Rule dm_abstractcs_cmderr_w1c: "The bits in this field remain set
# until they are cleared by writing 1 to them."
#
# cmderr is R/W1C: "Writing 0 to every bit has no effect. Writing 1 to
# every bit clears the field. The result of other writes is undefined."
# So only those two writes are tested: with cmderr=2 (not supported)
# and with cmderr=3 (exception), writing 0 keeps the value and writing
# 0x700 clears it.
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
dmi_wr $DM_ABSTRACTCS 0x700
dmi_rd $DM_ABSTRACTCS
check_cmderr
cmd_wait [access_reg_cmd 0x600 $XSZ 0]
check_cmderr
dmi_wr $DM_ABSTRACTCS 0
dmi_rd $DM_ABSTRACTCS
check_cmderr
dmi_wr $DM_ABSTRACTCS 0x700
dmi_rd $DM_ABSTRACTCS
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
