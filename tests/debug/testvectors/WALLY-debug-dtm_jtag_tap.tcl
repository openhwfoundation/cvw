######################################################################
# WALLY-debug-dtm_jtag_tap
# Rule dtm_jtag_tap: "This Debug Transport Module is based around
#   a normal JTAG Test Access Port (TAP)."
# Checks the IEEE 1149.1 basics of the TAP: Capture-IR loads
# ...01, IDCODE (IR 0x01) is a 32-bit register with bit 0 set, and
# BYPASS (IR 0x1f) is a 1-bit register that captures 0.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# IEEE 1149.1: "the two least significant bits [of the IR capture value]
# shall be 01". OpenOCD's irscan returns no TDO (Spike captures 00001).
dtm_ir $IR_IDCODE
dtm_check 0x3 0x1
# IDCODE: 32 bits, bit 0 = 1. A 64-bit scan returns IDCODE, then the
# first 32 bits shifted in.
dtm_dr 64 0x0123456789abcdef
dtm_check 0xffffffff00000001
dtm_ir $IR_BYPASS
dtm_check 0x3 0x1
# BYPASS: 1 bit, captures 0 (Spike: 0 here, its first BYPASS scan).
dtm_dr 16 0xa5c3
dtm_check 0xffff 0x4b86

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
