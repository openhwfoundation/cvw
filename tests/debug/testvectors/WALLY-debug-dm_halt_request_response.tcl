######################################################################
# WALLY-debug-dm_halt_request_response
# Rule dm_halt_request_response:
#   "When a running hart, or a hart just coming out of reset, sees its
#   halt request bit high, it responds by halting, deasserting its
#   running signal, and asserting its halted signal."
# Test: (1) running hart, haltreq=1: it halts (running clear, halted set).
# (2) haltreq=1 across an ndmreset: the hart coming out of reset
# halts.
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
resume_hart
ndmreset_pulse $HALTREQ
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
