######################################################################
# WALLY-debug-dm_dmcontrol_setresethaltreq_new_hartsel
# Rule dm_dmcontrol_setresethaltreq_new_hartsel:
#   "Writes apply to the new value of hartsel and hasel."
# Test: writes setresethaltreq together with hartsel = all ones (legalized
# to 0 by HARTSELLEN=0): the write applies to the new hartsel, hart 0,
# so the next ndmreset halts it.
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

# Wally sets dmstatus.hasresethaltreq; Spike doesn't implement
# halt-on-reset, so the expectations after a reset with resethaltreq
# set are the spec values.
dmc_wr [expr {$SETRESETHALTREQ | $HARTSELLO | $HARTSELHI}]
dmc_wr 0
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
clr_resethaltreq
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
