######################################################################
# WALLY-debug-Sdext_step_trap
# Rule Sdext_step_trap: "If control is transferred to a trap handler
# while executing the instruction, then Debug Mode is re-entered
# immediately after the PC is changed to the trap handler, and the
# appropriate tval and cause registers are updated. In this case
# none of the trap handler is executed, and if the cause was a
# pending interrupt no instructions might be executed at all."
#
# Step over an instruction that traps: an illegal instruction in
# M-mode, and an ecall in U-mode. Each time the hart must halt with
# dpc = the trap handler (mtvec), mcause/mepc/mtval updated,
# dcsr.prv = M (the handler's mode), and no handler instruction
# executed (s11=0).
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
wr $CSR_MCAUSE 0
wr $CSR_MTVAL 0
sd_run [lbl m_illegal] 3 ebreakall step
check_rd $CSR_DPC
check_rd $CSR_MCAUSE
check_rd $CSR_MEPC
check_rd $CSR_MTVAL
check_rd [gpr s11]
sd_run [lbl u_ecall] 0 ebreakall step
check_rd $CSR_DPC
check_rd $CSR_MCAUSE
check_rd $CSR_MEPC
check_rd $CSR_DCSR $DCSR_PRV
check_rd [gpr s11]
sd_finish
