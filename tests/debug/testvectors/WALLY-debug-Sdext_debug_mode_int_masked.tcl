######################################################################
# WALLY-debug-Sdext_debug_mode_int_masked
# Rule Sdext_debug_mode_int_masked: "All interrupts (including NMI)
# are masked."
#
# Halt in M-mode, then make a supervisor software interrupt pending
# and enabled (mstatus.MIE=1, mie.SSIE=1, mip.SSIP=1) while in Debug
# Mode. Check that the hart stays halted and mcause/mepc are
# untouched. After resume the interrupt is taken (s3 = mcause
# recorded by the handler).
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
sd_run [lbl probe] 3 ebreakm
wr $CSR_MCAUSE 0
wr $CSR_MEPC 0
set ms [rd $CSR_MSTATUS]
wr $CSR_MSTATUS [expr {$ms | $MSTATUS_MIE}]
wr $CSR_MIE 2
wr $CSR_MIP 2
rd [gpr s2]
rd [gpr s2]
check_halted
check_rd $CSR_MCAUSE
check_rd $CSR_MEPC
sd_run [lbl after] 3 ebreakm
check_rd [gpr s3]
sd_finish
