######################################################################
# WALLY-debug-dtm_dtmcs_errinfo_rst
# Rule dtm_dtmcs_errinfo_rst: "4: This is the reset value if the
#   field is implemented."
# Wally implements errinfo, so it must read 4 at the start of the
# test and right after dtmhardreset (which returns the DTM's
# registers to their reset values).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# Spec values: Wally implements errinfo (Spike's reads 0)
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0x1c0000 [expr {4 << 18}]
dtm_dr 32 [expr {1 << 17}]
dtm_dr 32 0
dtm_check 0x1c0000 [expr {4 << 18}]

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
