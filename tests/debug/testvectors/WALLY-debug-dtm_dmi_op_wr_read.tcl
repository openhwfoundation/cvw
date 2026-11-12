######################################################################
# WALLY-debug-dtm_dmi_op_wr_read
# Rule dtm_dmi_op_wr_read: "1 (read): Read from address."
# A dmi read of data1 must return data1's value, written before
# with a dmi write.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dtm_ir $IR_DMI
dmi_scan $DM_DATA1 0x2468ace0 2
dmi_scan $DM_DATA1 0 1
dmi_scan 0 0 0
dtm_check 0x3fffffffc

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
