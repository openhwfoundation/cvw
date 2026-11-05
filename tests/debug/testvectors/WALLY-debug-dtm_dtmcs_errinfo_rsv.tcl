######################################################################
# WALLY-debug-dtm_dtmcs_errinfo_rsv
# Rule dtm_dtmcs_errinfo_rsv: "errinfo: Other values (5-7) are
#   reserved for future use by this specification."
# Reads errinfo in every DTM state the tests can reach (start,
# after a write, a read, a nop, a fast back-to-back read,
# dmireset, dtmhardreset): it must read 4 each time, never a
# reserved value.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# Spec values: Wally implements errinfo (Spike's reads 0)
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0x1c0000 [expr {4 << 18}]
foreach op {2 1 0} {
    dtm_ir $IR_DMI
    dmi_scan $DM_DATA0 0x5 $op
    dtm_ir $IR_DTMCS
    dtm_dr 32 0
    dtm_check 0x1c0000 [expr {4 << 18}]
}
# a read collected with no Run-Test/Idle at a fast TCK
dtm_ir $IR_DMI
dtm_tck 8
dtm_rti 0
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_tck 52
dtm_rti 1
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0x1c0000 [expr {4 << 18}]
foreach bit {16 17} {
    dtm_dr 32 [expr {1 << $bit}]
    dtm_dr 32 0
    dtm_check 0x1c0000 [expr {4 << 18}]
}

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
