######################################################################
# WALLY-debug-dm_dmcs2_dmexttrigger_invalid
# Rule dm_dmcs2_dmexttrigger_invalid:
#   "If a non-existent trigger value is written here, the hardware
#   will change it to a valid one or 0 if no DM external triggers
#   exist."
# Test: there are no DM external triggers: dmexttrigger written all ones
# reads 0.
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

dmi_wr $DM_DMCS2 [expr {0xf << 7}]
dmi_rd $DM_DMCS2
tv_check $DM_DMCS2 [expr {0xf << 7}] 0
dmi_wr $DM_DMCS2 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
