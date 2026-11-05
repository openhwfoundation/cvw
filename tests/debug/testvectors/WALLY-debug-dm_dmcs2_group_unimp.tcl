######################################################################
# WALLY-debug-dm_dmcs2_group_unimp
# Rule dm_dmcs2_group_unimp:
#   "If groups aren't implemented, then this entire field is 0."
# Test: groups are not implemented: group reads 0 after writing group = all
# ones with hgwrite=1, for grouptype 0 and 1 and hgselect 0 and 1.
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

foreach gt {0 1} {
    foreach hs {0 1} {
        dmi_wr $DM_DMCS2 [expr {($gt << 11) | (0x1f << 2) | 2 | $hs}]
        dmi_rd $DM_DMCS2
        tv_check $DM_DMCS2 [expr {0x1f << 2}] 0
    }
}
dmi_wr $DM_DMCS2 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
