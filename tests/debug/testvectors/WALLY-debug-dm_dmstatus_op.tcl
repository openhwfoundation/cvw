######################################################################
# WALLY-debug-dm_dmstatus_op
# Rule dm_dmstatus_op:
#   "This register reports status for the overall Debug Module as well
#   as the currently selected harts, as defined in hasel."
# Test: dmstatus reports the selected hart (hasel=0, hartsel=0): running,
# then halted after haltreq, then running after resumereq.
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
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
halt_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
resume_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
