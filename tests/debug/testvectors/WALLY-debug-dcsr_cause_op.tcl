######################################################################
# WALLY-debug-dcsr_cause_op
# Rule dcsr_cause_op: "Explains why Debug Mode was entered."
#
# dcsr.cause records why Debug Mode was entered and is read-only.
# Halt by haltreq (cause 3), then write dcsr with cause=7: the read-
# back cause must still be 3.
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
set_dcsr 3 ebreakm $DCSR_CAUSE
check_rd $CSR_DCSR $DCSR_CAUSE
sd_finish
