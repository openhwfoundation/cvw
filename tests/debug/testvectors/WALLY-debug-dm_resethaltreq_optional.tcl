######################################################################
# WALLY-debug-dm_resethaltreq_optional
# Rule dm_resethaltreq_optional:
#   "The DM can implement optional halt-on-reset bits for each hart,
#   which it indicates by setting hasresethaltreq to 1. This means the
#   DM implements the setresethaltreq and clrresethaltreq bits."
# Test: hasresethaltreq reads 1, so setresethaltreq/clrresethaltreq are
# implemented: setresethaltreq then ndmreset leaves the hart halted.
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

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
