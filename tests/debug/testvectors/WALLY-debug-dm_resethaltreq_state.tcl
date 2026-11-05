######################################################################
# WALLY-debug-dm_resethaltreq_state
# Rule dm_resethaltreq_state:
#   "resethaltreq is an optional internal bit of per-hart state that
#   cannot be read, but can be written with setresethaltreq and
#   clrresethaltreq."
# Test: resethaltreq cannot be read (setresethaltreq/clrresethaltreq read 0
# after the write) but is written by setresethaltreq: the next
# ndmreset halts the hart.
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
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$SETRESETHALTREQ | $CLRRESETHALTREQ}] 0
# Wally sets dmstatus.hasresethaltreq; Spike doesn't implement
# halt-on-reset, so the expectations after a reset with resethaltreq
# set are the spec values.
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
clr_resethaltreq
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$SETRESETHALTREQ | $CLRRESETHALTREQ}] 0
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
