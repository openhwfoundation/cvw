######################################################################
# WALLY-debug-dm_dmcs2_group_halt_unimp
# Rule dm_dmcs2_group_halt_unimp:
#   "If halt groups are not implemented, then group will always be 0
#   when grouptype is 0."
# Test: halt groups are not implemented: writing group = all ones with
# hgwrite=1 and grouptype=0 leaves group 0 (read with grouptype=0).
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

dmi_wr $DM_DMCS2 [expr {(0x1f << 2) | 2}]
dmi_rd $DM_DMCS2
tv_check $DM_DMCS2 [expr {(1 << 11) | (0x1f << 2)}] 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
