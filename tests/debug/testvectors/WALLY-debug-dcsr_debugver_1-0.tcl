######################################################################
# WALLY-debug-dcsr_debugver_1-0
# Rule dcsr_debugver_1-0: "Debug support exists as it is described
# in this document."
#
# Read dcsr: debugver must be 4 (debug support as described in
# version 1.0).
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
check_rd $CSR_DCSR 0xf0000000
sd_finish
