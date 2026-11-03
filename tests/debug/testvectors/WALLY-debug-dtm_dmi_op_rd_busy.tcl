######################################################################
# WALLY-debug-dtm_dmi_op_rd_busy
# Rule dtm_dmi_op_rd_busy: "3 (busy): A DMI operation was
#   attempted while a prior DMI operation was still in progress.
#   The data scanned into dmi in this access will be ignored."
# With TCK = 16 ns (1.6 Wally clocks) and no Run-Test/Idle, a dmi
# read of data1 is followed at once by a read of data0, whose
# Capture-DR comes before the first read can finish. The second
# scan must capture busy (op 3) or the first read's real result
# (address 0x05, data, op 0).
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
dmi_scan $DM_DATA0 0x44444444 2
dmi_scan $DM_DATA1 0x55555555 2
dmi_scan 0 0 0
dtm_tck 8
dtm_rti 0
dmi_scan $DM_DATA1 0 1
dmi_scan $DM_DATA0 0 1
dtm_check 0x1ffffffffff
dtm_alt 0x3 0x3
dtm_tck 52
dtm_rti 1
dmi_scan 0 0 0
dtmcs_write [expr {1 << 16}]

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
