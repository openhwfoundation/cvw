######################################################################
# WALLY-debug-dtm_dtmcs_idle_enc
# Rule dtm_dtmcs_idle_enc: "idle 0: It is not necessary to enter
#   Run-Test/Idle at all. 1: Enter Run-Test/Idle and leave it
#   immediately. ..."
# Wally's dtmcs.idle is 0, so scans that go from Update-DR
# straight to Select-DR-Scan (no Run-Test/Idle) must work: a dmi
# write, read and nop back to back return op=0 and the written
# data.
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
dtm_dr 32 0
dtm_check 0x7000
dtm_ir $IR_DMI
# idle = 0: never enter Run-Test/Idle
dtm_rti 0
dmi_scan $DM_DATA0 0xcafe0001 2
dmi_scan $DM_DATA0 0 1
dtm_check 0x3
dmi_scan 0 0 0
dtm_check 0x1ffffffffff
dtm_rti 1

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
