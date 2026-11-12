######################################################################
# WALLY-debug-dcsr_stepie_interrupts_disabled
# Rule dcsr_stepie_interrupts_disabled: "Interrupts (including NMI)
# are disabled during single stepping with step set. This value
# should be supported."
#
# With an interrupt pending and enabled (mstatus.MIE=1, mie.SSIE=1,
# mip.SSIP=1) and dcsr.stepie=0, step one instruction. The interrupt
# must not be taken: dpc = the next instruction, the stepped addi
# executed (s6=1), mcause unchanged, dcsr.cause=4.
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
sd_run [lbl probe] 3 ebreakall step
# Spec: stepie=0 "Interrupts (including NMI) are disabled during single
# stepping with step set." So the addi executes and the step ends at
# the next instruction with no trap. Spike ignores stepie (reads 0) and
# takes the interrupt while stepping.
check_rd $CSR_DPC -1 [expr {[lbl probe] + 4}]
check_rd $CSR_MCAUSE -1 0
check_rd [gpr s6] -1 1
check_rd $CSR_DCSR $DCSR_CAUSE
wr $CSR_MIP 0
sd_finish
