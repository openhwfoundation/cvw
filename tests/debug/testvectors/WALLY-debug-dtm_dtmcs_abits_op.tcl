######################################################################
# WALLY-debug-dtm_dtmcs_abits_op
# Rule dtm_dtmcs_abits_op: "abits: The size of address in dmi."
# dtmcs.abits must read 7, and dmi must be abits+34 = 41 bits: a
# 42-bit scan returns the first bit shifted in at TDO bit 41. Also
# checks that a 41-bit read returns the 7-bit address.
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
dtm_check 0x3f0
dtm_ir $IR_DMI
dmi_scan $DM_DATA1 0x0badf00d 2
dmi_scan $DM_DATA1 0 1
dmi_scan 0 0 0
dtm_check 0x1ffffffffff
# 42-bit scan: bit 0 (=1) comes out at bit 41; the 41 bits left in dmi
# are 0 (a nop).
dtm_dr 42 0x1
dtm_check 0x20000000000

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
