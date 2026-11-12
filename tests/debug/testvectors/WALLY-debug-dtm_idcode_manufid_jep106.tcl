######################################################################
# WALLY-debug-dtm_idcode_manufid_jep106
# Rule dtm_idcode_manufid_jep106: "Bits 6:0 must be bits 6:0 of
#   the designer/manufacturer's Identification Code as assigned by
#   JEDEC Standard JEP106."
# Wally's designer is the OpenHW Group, JEP106 bank 13 code 0x02
# (Wally's mvendorid is 0x602). IDCODE[7:1] = ManufId[6:0] must be
# 0x02.
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
# Spec value for OpenHW: ManufId[6:0] = 0x02 (Spike's 0xdeadbeef is a
# placeholder)
dtm_check 0xfe [expr {0x02 << 1}]

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
