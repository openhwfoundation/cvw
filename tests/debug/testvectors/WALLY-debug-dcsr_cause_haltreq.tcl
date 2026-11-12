######################################################################
# WALLY-debug-dcsr_cause_haltreq
# Rule dcsr_cause_haltreq: "The debugger requested entry to Debug
# Mode using haltreq."
#
# Halt with dmcontrol.haltreq while the hart runs code in M-mode and
# in U-mode. dcsr.cause must be 3 both times.
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
check_rd $CSR_DCSR $DCSR_CAUSE
sd_go [lbl spin] 0 ebreakall
sleep 100
halt_hart
check_rd $CSR_DCSR $DCSR_CAUSE
sd_finish
