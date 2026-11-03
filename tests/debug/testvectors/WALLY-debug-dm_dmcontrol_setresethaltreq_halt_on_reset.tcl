######################################################################
# WALLY-debug-dm_dmcontrol_setresethaltreq_halt_on_reset
# Rule dm_dmcontrol_setresethaltreq_halt_on_reset:
#   "When set to 1, each selected hart will halt upon the next
#   deassertion of its reset."
# Test: (1) after an ndmreset (havereset still set, not acknowledged) the
# hart runs; setresethaltreq must not halt it, because the halt
# happens only upon the next deassertion of reset. (2) The next
# ndmreset then leaves it halted.
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

ndmreset_pulse
wait_running
set_resethaltreq
for {set i 0} {$i < 4} {incr i} { dmi_rd $DM_DMSTATUS }
# "each selected hart will halt upon the next deassertion of its
# reset": no reset has happened since setresethaltreq, so the hart
# keeps running.
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
# Wally sets dmstatus.hasresethaltreq; Spike doesn't implement
# halt-on-reset, so the expectations after a reset with resethaltreq
# set are the spec values.
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
clr_resethaltreq
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
