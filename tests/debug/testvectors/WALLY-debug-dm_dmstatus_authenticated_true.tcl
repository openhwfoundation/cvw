######################################################################
# WALLY-debug-dm_dmstatus_authenticated_true
# Rule dm_dmstatus_authenticated_true:
#   "The authentication check has passed."
# Test: authenticated reads 1 (no authentication required) and the DM can be
# used: the hart halts on haltreq.
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
tv_check $DM_DMSTATUS $AUTHENTICATED $AUTHENTICATED
halt_hart
tv_check $DM_DMSTATUS [expr {$AUTHENTICATED | $HARTSTATE_MASK}] [expr {$AUTHENTICATED | $STATE_HALTED}]

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
