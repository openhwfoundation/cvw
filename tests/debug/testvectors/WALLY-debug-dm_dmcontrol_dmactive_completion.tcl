######################################################################
# WALLY-debug-dm_dmcontrol_dmactive_completion
# Rule dm_dmcontrol_dmactive_completion:
#   "Hardware may take an arbitrarily long time to complete activation
#   or deactivation and will indicate completion by setting dmactive
#   to the requested value."
# Test: writes dmactive=0 and polls until dmcontrol.dmactive reads 0, then
# writes 1 and polls until it reads 1.
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

dmi_wr $DM_DMCONTROL 0
poll_until $DM_DMCONTROL 1 0
tv_check $DM_DMCONTROL 1 0
dmi_wr $DM_DMCONTROL 1
poll_until $DM_DMCONTROL 1 1
tv_check $DM_DMCONTROL 1 1

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
