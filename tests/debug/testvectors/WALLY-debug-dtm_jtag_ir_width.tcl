######################################################################
# WALLY-debug-dtm_jtag_ir_width
# Rule dtm_jtag_ir_width: "JTAG TAPs used as a DTM must have an IR
#   of at least 5 bits."
# A 10-bit IR scan of all ones returns the 5-bit capture value
# (..01) followed by the first five ones, so the IR is 5 bits
# long; IR 0x10 then selects dtmcs (bit 4 of the IR is decoded).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# OpenOCD scans the IR with irlen 5 and can't do a 10-bit IR scan, so
# the testbench does it alone. A 5-bit IR shifts out its capture value
# (IEEE 1149.1: two LSBs 01) and then TDI bits 0-4 (all ones).
dtm_ir_unscanned 10 0x3ff
dtm_check 0x3e3 0x3e1
# IR 0x10 (bit 4 set) selects dtmcs: version 1, abits 7.
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0x3ff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
