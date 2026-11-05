######################################################################
# WALLY-debug-dm_hart_state_running
# Rule dm_hart_state_running:
#   "Harts are running when they are executing normally, as if no
#   debugger was attached. This includes being in a low power mode or
#   waiting for an interrupt, as long as a halt request will result in
#   the hart being halted."
# Test: the hart sits in wfi (no interrupts enabled). dmstatus reports it
# running, and a halt request halts it.
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
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
dmc_wr $HALTREQ
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
