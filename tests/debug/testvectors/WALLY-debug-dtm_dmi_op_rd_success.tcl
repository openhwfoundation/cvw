######################################################################
# WALLY-debug-dtm_dmi_op_rd_success
# Rule dtm_dmi_op_rd_success: "0 (success): The previous operation
#   completed successfully."
# A dmi write and a read of data0 at the normal TCK must report op
# 0, and the read's data must be the value written (the operation
# did complete).
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
dmi_scan $DM_DATA0 0x76543210 2
dmi_scan $DM_DATA0 0 1
dtm_check 0x3
dmi_scan 0 0 0
dtm_check 0x1ffffffffff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
