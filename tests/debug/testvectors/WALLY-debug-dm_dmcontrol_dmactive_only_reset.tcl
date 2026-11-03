######################################################################
# WALLY-debug-dm_dmcontrol_dmactive_only_reset
# Rule dm_dmcontrol_dmactive_only_reset:
#   "No other mechanism should exist that may result in resetting the
#   Debug Module after power up."
# Test: an ndmreset (the platform reset) does not reset the DM: data0 and
# dmcontrol.dmactive keep their values across it.
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

dmi_wr $DM_DATA0 0x13579bdf
ndmreset_pulse
wait_running
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $DMACTIVE 1
dmi_rd $DM_DATA0
tv_check $DM_DATA0 0xffffffff 0x13579bdf
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
