######################################################################
# WALLY-debug-Sdext_csr_mode
# Rule Sdext_csr_mode: "These registers are only accessible from
# Debug Mode."
#
# From M-mode (not Debug Mode), read dcsr, dpc, dscratch0, dscratch1
# and write dcsr and dpc. Each must raise an illegal instruction
# exception: 6 traps, last mcause=2. dcsr must be unchanged by the
# write attempt.
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
sd_run [lbl probe] 3 ebreakall
check_rd [gpr s2]
check_rd [gpr s3]
check_rd $CSR_DCSR $DCSR_EBREAKALL
sd_finish
