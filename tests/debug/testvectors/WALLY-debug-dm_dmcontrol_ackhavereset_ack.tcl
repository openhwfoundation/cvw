######################################################################
# WALLY-debug-dm_dmcontrol_ackhavereset_ack
# Rule dm_dmcontrol_ackhavereset_ack:
#   "Clears havereset for any selected harts."
# Test: after an ndmreset (havereset set), writes ackhavereset=1: havereset
# clears for the selected hart.
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

ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HAVERESET_MASK $HAVERESET_MASK
dmc_wr $ACKHAVERESET
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HAVERESET_MASK 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
