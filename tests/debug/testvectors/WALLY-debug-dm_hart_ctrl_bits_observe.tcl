######################################################################
# WALLY-debug-dm_hart_ctrl_bits_observe
# Rule dm_hart_ctrl_bits_observe:
#   "The debugger can observe the state of resume ack in allresumeack
#   and anyresumeack, and the state of halted, running, and havereset
#   signals in allhalted, anyhalted, allrunning, anyrunning,
#   allhavereset, and anyhavereset."
# Test: observes resume ack (allresumeack/anyresumeack after a resume), the
# halted and running signals (allhalted.. anyrunning), and havereset
# (allhavereset/anyhavereset after ndmreset) in dmstatus.
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
resume_hart
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_RUNNING | $RESUMEACK_MASK}]
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HAVERESET_MASK $HAVERESET_MASK
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
