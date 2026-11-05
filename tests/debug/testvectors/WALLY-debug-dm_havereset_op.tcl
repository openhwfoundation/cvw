######################################################################
# WALLY-debug-dm_havereset_op
# Rule dm_havereset_op:
#   "When harts have been reset, they must set a sticky havereset
#   state bit. The conceptual havereset state bits can be read for
#   selected harts in anyhavereset and allhavereset in dmstatus. These
#   bits must be set regardless of the cause of the reset."
# Test: havereset is clear (acknowledged by OpenOCD's examine); pulses
# ndmreset and checks allhavereset = anyhavereset = 1 (sticky, still
# set after the hart runs and is halted and resumed); then
# acknowledges.
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
tv_check $DM_DMSTATUS $HAVERESET_MASK 0
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HAVERESET_MASK $HAVERESET_MASK
halt_hart
resume_hart
tv_check $DM_DMSTATUS $HAVERESET_MASK $HAVERESET_MASK
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
