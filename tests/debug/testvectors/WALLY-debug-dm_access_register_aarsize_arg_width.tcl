######################################################################
# WALLY-debug-dm_access_register_aarsize_arg_width
# Rule dm_access_register_aarsize_arg_width: "This field controls the
# Argument Width as referenced in xref:tab:datareg[]."
#
# aarsize sets the argument width: aarsize=2 uses data0 only (data1
# untouched on a read of x24); aarsize=3 uses data1:data0 (read of
# f15, write+read of f16).
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
dmi_wr $DM_DATA1 0xa5a5a5a5
cmd_wait [access_reg_cmd [gpr 24] 2 0]
check_cmderr
check_data 3
cmd_wait [access_reg_cmd [fpr 15] 3 0]
check_cmderr
check_data 3
set_arg0 3 0x0123456789abcdef
cmd_wait [access_reg_cmd [fpr 16] 3 1]
check_cmderr
set_arg0 3 0
cmd_wait [access_reg_cmd [fpr 16] 3 0]
check_cmderr
check_data 3

clear_cmderr
finish_test $objdump_file $XSZ
