######################################################################
# WALLY-debug-dtm_dtmcs_dmistat_op
# Rule dtm_dtmcs_dmistat_op: "dmistat: Read-only alias of op."
# After a successful dmi read, dtmcs.dmistat must equal the op
# just captured (0). Writing ones to the dmistat bits must not
# change dmistat or dmi.op.
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
dmi_scan $DM_DATA0 0x600df00d 2
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_check 0x3
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0xc00
# read-only: write 3 to dmistat (no dmireset/dtmhardreset)
dtm_dr 32 0xc00
dtm_dr 32 0
dtm_check 0xc00
dtm_ir $IR_DMI
dmi_scan 0 0 0
dtm_check 0x3

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
