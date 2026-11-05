######################################################################
# WALLY-debug-dm_dmcontrol_dmactive_active
# Rule dm_dmcontrol_dmactive_active:
#   "The module functions normally."
# Test: resets the DM (dmactive 0 then 1); with dmactive=1 the DM works: the
# hart can be halted and resumed.
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

dm_reset
halt_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
resume_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
