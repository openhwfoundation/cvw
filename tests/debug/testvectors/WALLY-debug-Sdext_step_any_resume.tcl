######################################################################
# WALLY-debug-Sdext_step_any_resume
# Rule Sdext_step_any_resume: "If step is set when a hart resumes
# then it will single step, regardless of the reason for resuming."
#
# With dcsr.step=1, resume at m_code. The hart executes one
# instruction and halts again: dcsr.cause=4, dpc = the next
# instruction, s2=1 and s3=0.
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
sd_run [lbl m_code] 3 ebreakm step
check_rd $CSR_DCSR $DCSR_CAUSE
check_rd $CSR_DPC
check_rd [gpr s2]
check_rd [gpr s3]
sd_finish
