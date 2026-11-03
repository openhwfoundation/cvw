######################################################################
# WALLY-debug-dtm_dmi_data_op
# Rule dtm_dmi_data_op: "data: The data to send to the DM over the
#   DMI during Update-DR, and the data returned from the DM as a
#   result of the previous operation."
# Sends a value to data0 in a dmi write and checks the data
# returned by the following read.
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
dmi_scan $DM_DATA0 0xa5a55a5a 2
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_check 0x3fffffffc

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
