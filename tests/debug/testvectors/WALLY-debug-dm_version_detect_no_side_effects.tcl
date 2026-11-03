######################################################################
# WALLY-debug-dm_version_detect_no_side_effects
# Rule dm_version_detect_no_side_effects:
#   "The meaning of the dmcontrol bits where hartreset, hasel,
#   hartsello, and hartselhi currently reside might change, but
#   preserving them will have no side effects. Clearing the bits of
#   dmcontrol not explicitly mentioned here will have no side effects
#   beyond the ones mentioned above."
# Test: deactivates the DM, then follows the version-detection procedure
# (read dmcontrol, write it with only dmactive set, poll dmactive,
# read dmstatus): version is 3 and the running hart is not affected
# (still running, havereset 0).
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
set v [dmi_rd $DM_DMCONTROL]
dmi_wr $DM_DMCONTROL [expr {($v & ($HARTRESET | $HASEL | $HARTSELLO | $HARTSELHI)) | 1}]
poll_until $DM_DMCONTROL 1 1
dmi_rd $DM_DMSTATUS
# dmstatus.version 3 (1.0); Spike reports 2.
tv_check $DM_DMSTATUS [expr {0xf | $HARTSTATE_MASK | $HAVERESET_MASK}] [expr {3 | $STATE_RUNNING}]

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
