######################################################################
# WALLY-debug-Sdext_step_deferred_fetch_exc_trigger
# Rule Sdext_step_deferred_fetch_exc_trigger: "If the instruction
# that is executed causes the PC to change to an address where an
# instruction fetch causes an exception, that exception does not
# occur until the next time the hart is resumed. Similarly, a
# trigger at the new address does not fire until the hart actually
# attempts to execute that instruction."
#
# Step over a jalr to 0x40000000, where there is no memory. The step
# must end with dpc = 0x40000000, dcsr.cause=4 and no trap (mcause
# unchanged). The next step then takes the instruction access fault:
# dpc = trap handler, mcause=1, mepc=0x40000000.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
# No gdb/telnet/tcl servers: parallel vector generation would collide on their ports
gdb port disabled
telnet port disabled
tcl port disabled
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/sdext.tcl
tv_rule

sd_begin
wr [gpr s6] 0x40000000
wr $CSR_MCAUSE 0
sd_run [lbl m_jump] 3 ebreakall step
check_rd $CSR_DPC
check_rd $CSR_DCSR $DCSR_CAUSE
check_rd $CSR_MCAUSE
resume_hart
sd_wait_halted
check_rd $CSR_DPC
check_rd $CSR_MCAUSE
check_rd $CSR_MEPC
sd_finish
