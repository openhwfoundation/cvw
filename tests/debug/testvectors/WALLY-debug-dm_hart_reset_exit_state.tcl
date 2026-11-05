######################################################################
# WALLY-debug-dm_hart_reset_exit_state
# Rule dm_hart_reset_exit_state:
#   "When a hart comes out of reset and haltreq or resethaltreq are
#   set, the hart will immediately enter Debug Mode (halted state).
#   Otherwise, if the hart was initially running it will execute
#   normally (running state) and if the hart was initially halted it
#   should now be running but may be halted."
# Test: (1) pulses ndmreset while the hart runs with haltreq and
# resethaltreq clear: the hart is running afterwards. (2) pulses
# ndmreset with haltreq set: the hart is halted immediately, before
# executing an instruction: dpc is the reset vector
# (rvtest_entry_point) and the first instruction (li s1, 0x111) has
# not run (s1 = 0, its reset value).
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
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
ack_havereset
ndmreset_pulse $HALTREQ
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0
ack_havereset
abs_read $REG_DPC [xsize]
# "When a hart comes out of reset and haltreq ... [is] set, the hart
# will immediately enter Debug Mode": dpc is the first instruction
# after reset, Wally's reset vector rvtest_entry_point (Spike's reset
# vector is its boot ROM at 0x1000).
tv_check $DM_DATA0 0xffffffff $entry
abs_read $REG_S1 [xsize]
tv_check $DM_DATA0 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
