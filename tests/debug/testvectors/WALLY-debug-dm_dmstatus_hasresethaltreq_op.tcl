######################################################################
# WALLY-debug-dm_dmstatus_hasresethaltreq_op
# Rule dm_dmstatus_hasresethaltreq_op:
#   "1 if this Debug Module supports halt-on-reset functionality
#   controllable by the setresethaltreq and clrresethaltreq bits. 0
#   otherwise."
# Test: hasresethaltreq = 1, and the halt-on-reset function works through
# setresethaltreq (hart halted after ndmreset) and clrresethaltreq
# (hart running after the next ndmreset).
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

dmi_rd $DM_DMSTATUS
# Wally implements halt-on-reset (debug.sv); Spike does not (reads 0).
tv_check $DM_DMSTATUS $HASRESETHALTREQ $HASRESETHALTREQ
# Wally sets dmstatus.hasresethaltreq; Spike doesn't implement
# halt-on-reset, so the expectations after a reset with resethaltreq
# set are the spec values.
set_resethaltreq
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
clr_resethaltreq
ack_havereset
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
