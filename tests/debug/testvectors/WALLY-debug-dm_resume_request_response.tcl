######################################################################
# WALLY-debug-dm_resume_request_response
# Rule dm_resume_request_response:
#   "Harts respond by resuming, clearing their halted signal, and
#   asserting their running signal. At the end of this process the
#   resume ack bit is set. These status signals of all selected harts
#   are reflected in allresumeack, anyresumeack, allrunning, and
#   anyrunning."
# Test: halted hart, resumereq=1: halted clears, running sets, and resume
# ack (allresumeack, anyresumeack) is set.
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
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr $RESUMEREQ
poll_until $DM_DMSTATUS $ALLRESUMEACK $ALLRESUMEACK
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_RUNNING | $RESUMEACK_MASK}]

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
