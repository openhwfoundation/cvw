######################################################################
# WALLY-debug-dm_self_reset_groups
# Rule dm_self_reset_groups:
#   "When the DM is reset, all harts must be placed in the lowest-
#   numbered halt and resume groups that they can be in."
# Test: after a DM reset (dmactive 0 then 1) the hart is in the lowest halt
# group, 0 (groups are not implemented): dmcs2.group reads 0.
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

dm_reset
dmi_wr $DM_DMCS2 0
dmi_rd $DM_DMCS2
tv_check $DM_DMCS2 [expr {(1 << 11) | (0x1f << 2)}] 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
