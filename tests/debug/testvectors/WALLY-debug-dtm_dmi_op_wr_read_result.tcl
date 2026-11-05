######################################################################
# WALLY-debug-dtm_dmi_op_wr_read_result
# Rule dtm_dmi_op_wr_read_result: "When this operation succeeds,
#   address contains the address that was read from, and data
#   contains the value that was read."
# After a successful read of data0, the next capture must hold
# address 0x04, the value read, and op 0.
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
dmi_scan $DM_DATA0 0x0c0ffee0 2
dmi_scan $DM_DATA0 0 1
dmi_scan $DM_DATA1 0 0
dtm_check 0x1ffffffffff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
