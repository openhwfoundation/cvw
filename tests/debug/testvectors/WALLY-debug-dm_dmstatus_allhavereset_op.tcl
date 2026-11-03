######################################################################
# WALLY-debug-dm_dmstatus_allhavereset_op
# Rule dm_dmstatus_allhavereset_op:
#   "This field is 1 when all currently selected harts have been reset
#   and reset has not been acknowledged for any of them."
# Test: allhavereset is 0 after havereset was acknowledged, 1 after an
# ndmreset, and 0 again after ackhavereset.
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
tv_check $DM_DMSTATUS $ALLHAVERESET 0
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $ALLHAVERESET $ALLHAVERESET
ack_havereset
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $ALLHAVERESET 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
