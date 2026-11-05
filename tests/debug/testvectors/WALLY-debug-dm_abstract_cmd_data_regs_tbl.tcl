######################################################################
# WALLY-debug-dm_abstract_cmd_data_regs_tbl
# Rule dm_abstract_cmd_data_regs_tbl: "Argument Width|arg0/return
# value|arg1|arg2 === 32|data0|data1|data2¶64|data0, data1|data2,
# data3|data4, data5¶128|data0-data3|data4-data7|data8-data11 ==="
#
# A 32-bit argument is data0 only (data1 keeps its value); a 64-bit
# argument is data0 (low) and data1 (high).
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
dmi_wr $DM_DATA0 0
dmi_wr $DM_DATA1 0xdeadbeef
cmd_wait [access_reg_cmd [gpr 9] 2 0]
check_cmderr
dmi_rd $DM_DATA0
tv_check $DM_DATA0 0xffffffff
dmi_rd $DM_DATA1
tv_check $DM_DATA1 0xffffffff
if {$ISA32} { set r [fpr 9] } else { set r [gpr 9] }
cmd_wait [access_reg_cmd $r 3 0]
check_cmderr
check_data 3

clear_cmderr
finish_test $objdump_file $XSZ
