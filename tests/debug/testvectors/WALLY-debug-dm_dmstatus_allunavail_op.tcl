######################################################################
# WALLY-debug-dm_dmstatus_allunavail_op
# Rule dm_dmstatus_allunavail_op:
#   "This field is 1 when all currently selected harts are
#   unavailable, or (if stickyunavail is 1) were unavailable without
#   that being acknowledged."
# Test: allunavail is 0: the selected hart is available while running and
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
tv_check $DM_DMSTATUS [expr {$ALLUNAVAIL | $STICKYUNAVAIL}] 0
halt_hart
tv_check $DM_DMSTATUS $ALLUNAVAIL 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
