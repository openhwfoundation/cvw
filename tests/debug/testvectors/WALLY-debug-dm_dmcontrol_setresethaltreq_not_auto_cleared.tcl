######################################################################
# WALLY-debug-dm_dmcontrol_setresethaltreq_not_auto_cleared
# Rule dm_dmcontrol_setresethaltreq_not_auto_cleared:
#   "The halt-on-reset request bit is not automatically cleared."
# Test: sets the halt-on-reset bit; ndmreset halts the hart; after
# acknowledging havereset and resuming, a second ndmreset halts it
# again (the bit was not cleared by the first halt).
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

set entry [get_address $objdump_file rvtest_entry_point]
# Wally sets dmstatus.hasresethaltreq; Spike doesn't implement
# halt-on-reset, so the expectations after a reset with resethaltreq
# set are the spec values.
set_resethaltreq
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
ack_havereset
# Restart at the reset vector (Wally leaves dpc = 0 after a
# halt-on-reset, see dm_resethaltreq_halt_on_reset; on Spike the hart
# isn't halted and the command fails).
abs_write $REG_DPC [xsize] $entry
clear_cmderr
resume_hart
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
clr_resethaltreq
ack_havereset

# Leave the test
halt_hart_twice
finish_test $objdump_file [xsize]
