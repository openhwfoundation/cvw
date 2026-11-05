######################################################################
# WALLY-debug-dm_dmcs2_grouptype_resume_unimp
# Rule dm_dmcs2_grouptype_resume_unimp:
#   "If resume groups are not implemented, then grouptype will remain
#   0 even after 1 is written there."
# Test: resume groups are not implemented: grouptype written 1 reads 0.
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

dmi_wr $DM_DMCS2 [expr {1 << 11}]
dmi_rd $DM_DMCS2
tv_check $DM_DMCS2 [expr {1 << 11}] 0
dmi_wr $DM_DMCS2 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
