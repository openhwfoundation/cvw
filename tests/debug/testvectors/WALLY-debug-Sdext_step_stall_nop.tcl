######################################################################
# WALLY-debug-Sdext_step_stall_nop
# Rule Sdext_step_stall_nop: "If the instruction being stepped over
# would normally stall the hart, then instead the instruction is
# treated as a nop. This includes wfi, wrs.sto, and wrs.nto."
#
# Step over a wfi in M-mode with no interrupt enabled. The wfi must
# act as a nop: the hart halts again with dcsr.cause=4 and dpc = the
# instruction after the wfi.
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
sd_run [lbl m_code] 3 ebreakm
sd_run [lbl m_wfi] 3 ebreakm step
check_rd $CSR_DCSR $DCSR_CAUSE
check_rd $CSR_DPC
sd_finish
