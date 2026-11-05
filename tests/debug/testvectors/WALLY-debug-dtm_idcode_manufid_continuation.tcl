######################################################################
# WALLY-debug-dtm_idcode_manufid_continuation
# Rule dtm_idcode_manufid_continuation: "Bits 10:7 contain the
#   modulo-16 count of the number of continuation characters
#   (0x7f) in that same Identification Code."
# OpenHW Group's JEP106 code is in bank 13, after 12 continuation
# characters. IDCODE[11:8] = ManufId[10:7] must be 12.
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
dtm_dr 32 0
# Spec value for OpenHW: 12 continuation characters (Spike's
# 0xdeadbeef is a placeholder)
dtm_check 0xf00 [expr {12 << 8}]

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
