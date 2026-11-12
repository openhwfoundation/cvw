######################################################################
# WALLY-debug-dm_resume_request_send
# Rule dm_resume_request_send:
#   "When a debugger writes 1 to resumereq, each selected hart's
#   resume ack bit is cleared and each selected, halted hart is sent a
#   resume request."
# Test: (1) halted hart, resumereq=1: it resumes and resume ack is set. (2)
# running hart (resume ack = 1), resumereq=1: resume ack is cleared
# and the hart keeps running.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
# No servers: concurrent generations would collide on their ports
gdb port disabled
telnet port disabled
tcl port disabled
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmrun.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

halt_hart
dmc_wr $RESUMEREQ
wait_running
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_RUNNING | $RESUMEACK_MASK}]
dmc_wr $RESUMEREQ
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] $STATE_RUNNING

# Leave the test
halt_hart_twice
finish_test $objdump_file [xsize]
