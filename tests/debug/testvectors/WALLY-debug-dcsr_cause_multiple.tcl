######################################################################
# WALLY-debug-dcsr_cause_multiple
# Rule dcsr_cause_multiple: "When there are multiple reasons to
# enter Debug Mode in a single cycle, hardware should set cause to
# the cause with the highest priority."
#
# Step (dcsr.step=1) over an ebreak in U-mode with ebreaku=1. Two
# reasons to enter Debug Mode occur together; dcsr.cause must be the
# higher-priority one, ebreak (1), not step (4).
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
sd_run [lbl probe_ebreak] 0 ebreakall step
check_rd $CSR_DCSR $DCSR_CAUSE
sd_finish
