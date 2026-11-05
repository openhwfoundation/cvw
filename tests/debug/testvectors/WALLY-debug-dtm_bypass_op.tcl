######################################################################
# WALLY-debug-dtm_bypass_op
# Rule dtm_bypass_op: "1-bit register that has no effect."
# With IR = BYPASS (0x1f), a 16-bit DR scan must return a captured
# 0 and then TDI delayed by one bit; data0 must be unchanged.
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
dmi_scan $DM_DATA0 0x0b0b0b0b 2
dtm_ir $IR_BYPASS
dtm_dr 16 0xa5c3
dtm_check 0xffff 0x4b86
dtm_ir $IR_DMI
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_check 0x3fffffffc

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
