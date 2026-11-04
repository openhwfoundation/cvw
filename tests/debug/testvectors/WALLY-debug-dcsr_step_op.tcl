######################################################################
# WALLY-debug-dcsr_step_op
# Rule dcsr_step_op: "When set and not in Debug Mode, the hart will
# only execute a single instruction and then enter Debug Mode."
#
# With dcsr.step=1, resume twice. Each resume executes exactly one
# instruction and re-enters Debug Mode: after two steps s2=1, s3=1,
# s4=0, and dpc = the third addi.
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
sd_run [lbl probe] 3 ebreakm step
resume_hart
sd_wait_halted
check_rd [gpr s2]
check_rd [gpr s3]
check_rd [gpr s4]
check_rd $CSR_DPC
sd_finish
