######################################################################
# WALLY-debug-dm_dmcs2_hgselect_rdonly0_no_triggers
# Rule dm_dmcs2_hgselect_rdonly0_no_triggers:
#   "If there are no DM external triggers, this field must be tied to
#   0."
# Test: there are no DM external triggers: hgselect written 1 reads 0.
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

dmi_wr $DM_DMCS2 1
dmi_rd $DM_DMCS2
tv_check $DM_DMCS2 1 0
dmi_wr $DM_DMCS2 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
