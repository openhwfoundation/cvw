######################################################################
# WALLY-debug-dm_dmcontrol_ndmreset_first_instr
# Rule dm_dmcontrol_ndmreset_first_instr:
#   "Exactly what is affected by this reset is implementation
#   dependent, but it must be possible to debug programs from the
#   first instruction executed."
# Test: uses the DM's halt-on-reset mechanism (Wally sets hasresethaltreq):
# sets resethaltreq, pulses ndmreset, and checks that the hart is
# halted with dpc at the first instruction executed after reset (the
# reset vector, rvtest_entry_point), which has not run yet (s1 = 0),
# so the program can be debugged from its first instruction.
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
# halt-on-reset, so the expectations after the reset are spec values.
set_resethaltreq
ndmreset_pulse
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
clr_resethaltreq
ack_havereset
halt_hart
abs_read $REG_DPC [xsize]
# The first instruction executed after reset is at Wally's reset
# vector, rvtest_entry_point.
tv_check $DM_DATA0 0xffffffff $entry
abs_read $REG_S1 [xsize]
# It is "li s1, 0x111", not yet executed: s1 keeps its reset value 0.
tv_check $DM_DATA0 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
