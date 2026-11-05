######################################################################
# WALLY-debug-dcsr_cause_ebreak
# Rule dcsr_cause_ebreak: "An ebreak instruction was executed."
#
# Run probe in M-mode with dcsr.ebreakm=1; the ebreak halts the
# hart. dcsr.cause must be 1.
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
sd_run [lbl probe] 3 ebreakm
check_rd $CSR_DCSR $DCSR_CAUSE
sd_finish
