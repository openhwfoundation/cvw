######################################################################
# WALLY-debug-dm_dmcontrol_clrresethaltreq_op
# Rule dm_dmcontrol_clrresethaltreq_op:
#   "This optional field clears the halt-on-reset request bit for all
#   currently selected harts."
# Test: sets then clears the halt-on-reset bit; the next ndmreset leaves the
# hart running.
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

set_resethaltreq
clr_resethaltreq
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
