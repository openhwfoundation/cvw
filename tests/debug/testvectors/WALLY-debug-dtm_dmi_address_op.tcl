######################################################################
# WALLY-debug-dtm_dmi_address_op
# Rule dtm_dmi_address_op: "address: Address used for DMI access.
#   In Update-DR this value is used to access the DM over the
#   DMI."
# Writes different values to data0 (0x04) and data1 (0x05) through
# dmi, then reads each: each read must return its own address's
# value.
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
dmi_scan $DM_DATA0 0xaaaa0004 2
dmi_scan $DM_DATA1 0xbbbb0005 2
dmi_scan $DM_DATA0 0 1
dmi_scan $DM_DATA1 0 1
dtm_check 0x1ffffffffff
dmi_scan 0 0 0
dtm_check 0x1ffffffffff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
