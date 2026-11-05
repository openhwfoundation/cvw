######################################################################
# WALLY-debug-dtm_idcode_ieee
# Rule dtm_idcode_ieee: "Its definition is exactly as defined in
#   IEEE Std 1149.1-2013."
# IEEE 1149.1 IDCODE: a 32-bit register whose bit 0 is 1. A 64-bit
# scan returns IDCODE followed by the first 32 bits shifted in.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dtm_ir $IR_IDCODE
dtm_dr 64 0x0123456789abcdef
dtm_check 0xffffffff00000001

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
