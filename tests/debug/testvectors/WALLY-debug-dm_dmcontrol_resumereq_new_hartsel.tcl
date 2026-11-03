######################################################################
# WALLY-debug-dm_dmcontrol_resumereq_new_hartsel
# Rule dm_dmcontrol_resumereq_new_hartsel:
#   "Writes apply to the new value of hartsel and hasel."
# Test: halted hart; writes resumereq=1 together with a new hartsel (all
# ones, legalized to 0): the resume applies to hart 0, which resumes.
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

halt_hart
dmc_wr [expr {$RESUMEREQ | $HARTSELLO | $HARTSELHI}]
poll_until $DM_DMSTATUS $ALLRESUMEACK $ALLRESUMEACK
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_RUNNING | $RESUMEACK_MASK}]
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
