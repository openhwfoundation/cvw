######################################################################
# WALLY-debug-dm_hart_state_dmstatus
# Rule dm_hart_state_dmstatus:
#   "Which state the selected harts are in is reflected by
#   allnonexistent, anynonexistent, allunavail, anyunavail,
#   allrunning, anyrunning, allhalted, and anyhalted."
# Test: checks all eight hart-state bits of dmstatus (15:8) as the selected
# hart goes running -> halted -> running.
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
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
dmc_wr $HALTREQ
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0
dmc_wr $RESUMEREQ
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
