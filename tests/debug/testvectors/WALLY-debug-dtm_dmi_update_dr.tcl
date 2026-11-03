######################################################################
# WALLY-debug-dtm_dmi_update_dr
# Rule dtm_dmi_update_dr: "In Update-DR, the DTM starts the
#   operation specified in op unless the current status reported
#   in op is sticky."
# With no sticky status, a dmi write and a dmi read must each be
# started by their own Update-DR: the read returns the value just
# written.
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
dmi_scan $DM_DATA0 0xfeedface 2
dmi_scan $DM_DATA0 0 1
dtm_check 0x3
dmi_scan 0 0 0
dtm_check 0x1ffffffffff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
