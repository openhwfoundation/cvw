######################################################################
# WALLY-debug-dtm_dtmcs_version_1-0
# Rule dtm_dtmcs_version_1-0: "1 (1.0): Version described in spec
#   versions 0.13 and 1.0."
# dtmcs.version must read 1.
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
dtm_check 0xf

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
