######################################################################
# WALLY-debug-dm_dmstatus_anyunavail_op
# Rule dm_dmstatus_anyunavail_op:
#   "This field is 1 when any currently selected hart is unavailable,
#   or (if stickyunavail is 1) was unavailable without that being
#   acknowledged."
# Test: anyunavail is 0: the selected hart is available while running and
# halted (stickyunavail = 0).
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

dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS [expr {$ANYUNAVAIL | $STICKYUNAVAIL}] 0
halt_hart
tv_check $DM_DMSTATUS $ANYUNAVAIL 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
