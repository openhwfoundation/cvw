######################################################################
# WALLY-debug-dm_halt_resume_latency
# Rule dm_halt_resume_latency:
#   "When halt or resume is requested, a hart must respond in less
#   than one second, unless it is unavailable."
# Test: bounds the halt and resume latency by one DMI access: the first
# dmstatus read after writing haltreq (resumereq) already shows the
# hart halted (running). That is far below one second.
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
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0
dmc_wr $RESUMEREQ
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_RUNNING | $RESUMEACK_MASK}]

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
