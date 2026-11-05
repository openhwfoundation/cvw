######################################################################
# WALLY-debug-dm_halt_request_set
# Rule dm_halt_request_set:
#   "When a debugger writes 1 to haltreq, each selected hart's halt
#   request bit is set."
# Test: writes haltreq=1 for the selected (running) hart: its halt request
# bit is set, so it halts.
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

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
