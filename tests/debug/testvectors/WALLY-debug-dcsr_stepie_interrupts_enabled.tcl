######################################################################
# WALLY-debug-dcsr_stepie_interrupts_enabled
# Rule dcsr_stepie_interrupts_enabled: "Interrupts (including NMI)
# are enabled during single stepping with step set."
#
# With an interrupt pending and enabled (mstatus.MIE=1, mie.SSIE=1,
# mip.SSIP=1) and dcsr.stepie=1 (Wally implements stepie), step. The
# interrupt is taken and the hart re-enters Debug Mode at the
# handler: dpc = mtvec, mcause = supervisor software interrupt, mepc
# = the addi, which did not execute (s6=0), and no handler
# instruction executed (s11=0).
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
set ms [rd $CSR_MSTATUS]
wr $CSR_MSTATUS [expr {$ms | $MSTATUS_MIE}]
wr $CSR_MIE 2
wr $CSR_MCAUSE 0
wr $CSR_MIP 2
sd_run [lbl probe] 3 ebreakall stepie step
# Spec (step bit): "If control is transferred to a trap handler while
# executing the instruction, then Debug Mode is re-entered immediately
# after the PC is changed to the trap handler ... none of the trap
# handler is executed". So dpc = trap_handler. Spike runs one handler
# instruction before halting (dpc = trap_handler+4).
check_rd $CSR_DPC -1 [lbl trap_handler]
check_rd $CSR_MCAUSE
check_rd $CSR_MEPC
check_rd [gpr s6]
check_rd [gpr s11]
wr $CSR_MIP 0
sd_finish
