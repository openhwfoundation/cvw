######################################################################
# WALLY-debug-dm_dmcontrol_haltreq_new_hartsel
# Rule dm_dmcontrol_haltreq_new_hartsel:
#   "Writes apply to the new value of hartsel and hasel."
# Test: writes haltreq=1 together with a new hartsel (all ones, legalized to
# 0 by HARTSELLEN=0): the request applies to the hart selected by the
# new value, hart 0, which halts.
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

dmc_wr [expr {$HALTREQ | $HARTSELLO | $HARTSELHI}]
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
