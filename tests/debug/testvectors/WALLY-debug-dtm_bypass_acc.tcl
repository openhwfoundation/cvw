######################################################################
# WALLY-debug-dtm_bypass_acc
# Rule dtm_bypass_acc: "BYPASS: This entire register is
#   read-only."
# Shifts a 1 into BYPASS as the last bit of a scan (it passes
# Update-DR), then scans again: BYPASS must still capture 0 (IEEE
# 1149.1: BYPASS loads 0 in Capture-DR).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dtm_ir $IR_BYPASS
dtm_dr 16 0xffff
# Spike's BYPASS captures the last bit shifted in (1); spec value 0
dtm_dr 16 0x0000
dtm_check 0x1 0x0

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
