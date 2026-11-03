######################################################################
# WALLY-debug-dtm_dmi_op_wr_nop_no_send
# Rule dtm_dmi_op_wr_nop_no_send: "nop: Don't send anything over
#   the DMI during Update-DR."
# Scans a nop whose address is dmcontrol and whose data sets
# haltreq. Had it been sent, the hart would halt; dmstatus must
# still show allrunning=1, allhalted=0.
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
dmi_scan $DM_DMCONTROL 0x80000001 0
dmi_scan 0 0 0
dmi_scan $DM_DMSTATUS 0 1
dmi_scan 0 0 0
dtm_check [expr {(1 << 11 | 1 << 9) << 2}]

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
