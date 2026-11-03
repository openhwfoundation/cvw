######################################################################
# WALLY-debug-dtm_dmi_op_wr_nop
# Rule dtm_dmi_op_wr_nop: "0 (nop): Ignore data and address."
# Writes data0, then scans a nop carrying data0's address and a
# different value; data0 must keep the written value.
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
dmi_scan $DM_DATA0 0x13579bdf 2
dmi_scan $DM_DATA0 0xffffffff 0
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_check 0x3fffffffc

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
