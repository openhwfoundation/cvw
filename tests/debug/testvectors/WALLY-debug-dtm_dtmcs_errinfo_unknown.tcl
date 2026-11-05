######################################################################
# WALLY-debug-dtm_dtmcs_errinfo_unknown
# Rule dtm_dtmcs_errinfo_unknown: "4 (unknown): There is no error
#   to report, or no further information available about the
#   error."
# With no DMI error (after successful writes and reads), errinfo
# must read 4.
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
dmi_scan $DM_DATA1 0x2 2
dmi_scan $DM_DATA1 0 1
dmi_scan 0 0 0
dtm_check 0x3
# Spec value: Wally implements errinfo (Spike's reads 0)
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0x1c0000 [expr {4 << 18}]

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
