######################################################################
# WALLY-debug-dtm_dtmcs_idle_op
# Rule dtm_dtmcs_idle_op: "idle: a hint to the debugger of the
#   minimum number of cycles a debugger should spend in
#   Run-Test/Idle after every DMI scan to avoid a busy return code
#   (dmistat of 3)."
# Reads dtmcs.idle and then does back-to-back dmi writes and reads
# with exactly that many Run-Test/Idle cycles between scans: none
# may return busy, and the reads must return the written data.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dtm_ir $IR_DTMCS
set dtmcs [dtm_dr 32 0]
dtm_check 0x7000
set idle [expr {($dtmcs >> 12) & 7}]
dtm_ir $IR_DMI
dtm_rti $idle
dmi_scan $DM_DATA0 0x11112222 2
dmi_scan $DM_DATA1 0x33334444 2
dtm_check 0x3
dmi_scan $DM_DATA0 0 1
dtm_check 0x3
dmi_scan $DM_DATA1 0 1
dtm_check 0x1ffffffffff
dmi_scan 0 0 0
dtm_check 0x1ffffffffff
dtm_rti 1

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
