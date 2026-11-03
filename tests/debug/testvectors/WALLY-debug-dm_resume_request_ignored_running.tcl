######################################################################
# WALLY-debug-dm_resume_request_ignored_running
# Rule dm_resume_request_ignored_running:
#   "Resume requests are ignored by running harts."
# Test: writes resumereq=1 to the running hart, then halts it with haltreq
# (kept set): the hart must halt and stay halted, and resume ack stays
# 0 because the resume request was ignored.
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
resume_hart
dmc_wr $RESUMEREQ
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
dmc_wr $HALTREQ
wait_halted
for {set i 0} {$i < 4} {incr i} { dmi_rd $DM_DMSTATUS }
# "Resume requests are ignored by running harts": no resume happens
# after the halt, so resume ack (cleared by the resumereq write)
# stays 0. Spike remembers the resume request and resumes the hart
# as soon as it halts, setting resume ack.
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] $STATE_HALTED
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
