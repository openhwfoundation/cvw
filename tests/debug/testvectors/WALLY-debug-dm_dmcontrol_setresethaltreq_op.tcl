######################################################################
# WALLY-debug-dm_dmcontrol_setresethaltreq_op
# Rule dm_dmcontrol_setresethaltreq_op:
#   "This optional field writes the halt-on-reset request bit for all
#   currently selected harts, unless clrresethaltreq is simultaneously
#   set to 1."
# Test: (1) setresethaltreq together with clrresethaltreq does not set the
# bit: after ndmreset the hart runs. (2) setresethaltreq alone sets
# it: after ndmreset the hart is halted.
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

dmc_wr [expr {$SETRESETHALTREQ | $CLRRESETHALTREQ}]
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
ack_havereset
# Wally sets dmstatus.hasresethaltreq; Spike doesn't implement
# halt-on-reset, so the expectations after a reset with resethaltreq
# set are the spec values.
set_resethaltreq
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
clr_resethaltreq
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
