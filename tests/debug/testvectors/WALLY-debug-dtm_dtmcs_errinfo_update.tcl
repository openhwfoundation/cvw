######################################################################
# WALLY-debug-dtm_dtmcs_errinfo_update
# Rule dtm_dtmcs_errinfo_update: "errinfo is updated whenever op
#   is updated by the hardware or when 1 is written to dmireset."
# After a dmi operation completes successfully (op updated to 0),
# errinfo must say there is no error (4); after dmireset it must
# be its reset value 4.
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
dmi_scan $DM_DATA0 0x1 2
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_check 0x3
# Spec values: Wally implements errinfo (Spike's reads 0)
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0x1c0000 [expr {4 << 18}]
dtm_dr 32 [expr {1 << 16}]
dtm_dr 32 0
dtm_check 0x1c0000 [expr {4 << 18}]

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
