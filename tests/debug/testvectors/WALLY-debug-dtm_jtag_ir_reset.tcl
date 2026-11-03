######################################################################
# WALLY-debug-dtm_jtag_ir_reset
# Rule dtm_jtag_ir_reset: "When the TAP is reset, IR must default
#   to 00001, selecting the IDCODE instruction."
# Selects dtmcs, resets the TAP with TMS high (Test-Logic-Reset),
# then scans 32 DR bits without an IR scan: they must be Wally's
# IDCODE.
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
dtm_tlr
# OpenOCD won't drscan after Test-Logic-Reset (it marks the TAP as in
# BYPASS), so only the testbench scans. Expected: the IDCODE register,
# Wally's preset value (Spike's is 0xdeadbeef).
dtm_dr_unscanned 32 0
dtm_check 0xffffffff $WALLY_IDCODE

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
