######################################################################
# WALLY-debug-dpc_ebreak
# Rule dpc_ebreak: "Address of the ebreak instruction"
#
# Halt on ebreak instructions (dcsr.ebreakm=1) and check that dpc =
# the ebreak's address: a 4-byte ebreak, a 2-byte c.ebreak, and an
# ebreak in the last word of a 64-byte line whose next line is not
# yet cached.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
# No gdb/telnet/tcl servers: parallel vector generation would collide on their ports
gdb port disabled
telnet port disabled
tcl port disabled
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/sdext.tcl
tv_rule

sd_begin
sd_run [lbl probe32] 3 ebreakm
check_rd $CSR_DPC
sd_run [lbl probe16] 3 ebreakm
check_rd $CSR_DPC
sd_run [lbl line_start] 3 ebreakm
check_rd $CSR_DPC
sd_finish
