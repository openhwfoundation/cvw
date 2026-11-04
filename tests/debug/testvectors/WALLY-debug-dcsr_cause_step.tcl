######################################################################
# WALLY-debug-dcsr_cause_step
# Rule dcsr_cause_step: "The hart single stepped because step was
# set."
#
# Step one instruction (dcsr.step=1) in M-mode and in S-mode.
# dcsr.cause must be 4 both times.
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
sd_run [lbl probe] 3 ebreakall step
check_rd $CSR_DCSR $DCSR_CAUSE
sd_run [lbl probe] 1 ebreakall step
check_rd $CSR_DCSR $DCSR_CAUSE
sd_finish
