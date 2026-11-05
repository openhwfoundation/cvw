######################################################################
# WALLY-debug-dtm_dmi_capture_dr
# Rule dtm_dmi_capture_dr: "In Capture-DR, the DTM updates data
#   with the result from that operation, updating op if the
#   current op isn't sticky."
# A dmi read of data1 followed by a nop must capture the read's
# result (address 0x05, the data, op 0). First at the normal TCK,
# then with TCK = 16 ns (1.6 Wally clocks) and no Run-Test/Idle,
# where the nop's Capture-DR comes before the read can finish: the
# DTM must then report busy (op 3) or the real result, never op 0
# with other data. A write at the fast TCK, read back slowly,
# shows the DTM handles scans at that speed.
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
dmi_scan $DM_DATA0 0x11111111 2
dmi_scan $DM_DATA1 0x22222222 2
dmi_scan $DM_DATA1 0 1
dmi_scan 0 0 0
dtm_check 0x1ffffffffff
# fast TCK, no Run-Test/Idle
dtm_tck 8
dtm_rti 0
dmi_scan $DM_DATA0 0x33333333 2
dmi_scan $DM_DATA1 0 1
dmi_scan 0 0 0
dtm_check 0x1ffffffffff
# "If the operation didn't complete in time, op will be 3 and the value
# in data must be ignored" (Debug Module Interface Access)
dtm_alt 0x3 0x3
dtm_tck 52
dtm_rti 1
# clear a sticky busy, if any
dtmcs_write [expr {1 << 16}]
# the write made at the fast TCK reached data0
dtm_ir $IR_DMI
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_check 0x3fffffffc

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
