######################################################################
# WALLY-debug-dtm_idcode_acc
# Rule dtm_idcode_acc: "This entire register is read-only."
# Shifts zeros, ones and a pattern through IDCODE (each scan
# passes Update-DR); every scan must still capture the preset
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

dtm_ir $IR_IDCODE
# Wally's preset IDCODE (Spike's is 0xdeadbeef)
dtm_dr 32 0x00000000
dtm_dr 32 0xffffffff
dtm_check 0xffffffff $WALLY_IDCODE
dtm_dr 32 0x5a5a5a5a
dtm_check 0xffffffff $WALLY_IDCODE
dtm_dr 32 0
dtm_check 0xffffffff $WALLY_IDCODE

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
