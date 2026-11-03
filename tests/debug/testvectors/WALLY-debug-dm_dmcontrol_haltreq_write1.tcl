######################################################################
# WALLY-debug-dm_dmcontrol_haltreq_write1
# Rule dm_dmcontrol_haltreq_write1:
#   "Writing 1 sets the halt request bit for all currently selected
#   harts. Running harts will halt whenever their halt request bit is
#   set."
# Test: writes haltreq=1 to the running selected hart: it halts.
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

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
