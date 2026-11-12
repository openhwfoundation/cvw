######################################################################
# WALLY-debug-dm_select_single_hart
# Rule dm_select_single_hart:
#   "All debug modules must support selecting a single hart."
# Test: selects hart 0 alone (hasel=0, hartsel=0), halts and resumes it, and
# checks dmstatus reports that hart halted and then running.
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

dmc_wr 0
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$HASEL | $HARTSELLO | $HARTSELHI}] 0
halt_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
resume_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
