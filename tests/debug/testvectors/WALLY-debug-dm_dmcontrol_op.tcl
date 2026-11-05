######################################################################
# WALLY-debug-dm_dmcontrol_op
# Rule dm_dmcontrol_op:
#   "This register controls the overall Debug Module as well as the
#   currently selected harts, as defined in hasel."
# Test: dmcontrol controls the selected hart: haltreq halts it, resumereq
# resumes it, ndmreset resets it (havereset).
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

dmc_wr $HALTREQ
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0
dmc_wr $RESUMEREQ
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HAVERESET_MASK $HAVERESET_MASK
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
