######################################################################
# WALLY-debug-dm_dmcontrol_dmactive_op
# Rule dm_dmcontrol_dmactive_op:
#   "This bit serves as a reset signal for the Debug Module itself."
# Test: writes data0, resets the DM (dmactive 0 then 1), and checks data0 is
# back at its reset value 0.
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

dmi_wr $DM_DATA0 0x12345678
dmi_rd $DM_DATA0
tv_check $DM_DATA0 0xffffffff 0x12345678
dm_reset
dmi_rd $DM_DATA0
# dmactive=0: "The module's state ... takes its reset values"; data0
# resets to 0. Spike keeps data0 across a DM reset.
tv_check $DM_DATA0 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
