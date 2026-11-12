######################################################################
# WALLY-debug-dm_resethaltreq_halt_on_reset
# Rule dm_resethaltreq_halt_on_reset:
#   "When a hart's halt-on-reset request bit is set, the hart will
#   immediately enter debug mode on the next deassertion of its reset.
#   This is true regardless of the reset's cause."
# Test: sets the halt-on-reset bit, pulses ndmreset, and checks the hart is
# halted with dpc at the reset vector (rvtest_entry_point): it entered
# Debug Mode immediately, before executing an instruction.
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
clr_resethaltreq
ack_havereset
halt_hart
abs_read $REG_DPC [xsize]
tv_check $DM_DATA0 0xffffffff $entry

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
