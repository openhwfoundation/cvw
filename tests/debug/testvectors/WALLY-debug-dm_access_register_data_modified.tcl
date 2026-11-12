######################################################################
# WALLY-debug-dm_access_register_data_modified
# Rule dm_access_register_data_modified: "This command modifies arg0
# only when a register is read. The other data registers are not
# changed."
#
# A 32-bit read changes only data0 (data1 kept); full-width GPR and
# 64-bit FPR writes change no data register.
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
dmi_wr $DM_DATA0 0x11111111
dmi_wr $DM_DATA1 0x22222222
cmd_wait [access_reg_cmd [gpr 14] 2 0]
check_cmderr
dmi_rd $DM_DATA1
tv_check $DM_DATA1 0xffffffff
dmi_wr $DM_DATA0 0x33333333
dmi_wr $DM_DATA1 0x44444444
cmd_wait [access_reg_cmd [gpr 15] $XSZ 1]
check_cmderr
check_data 3
cmd_wait [access_reg_cmd [fpr 10] 3 1]
check_cmderr
check_data 3

clear_cmderr
finish_test $objdump_file $XSZ
