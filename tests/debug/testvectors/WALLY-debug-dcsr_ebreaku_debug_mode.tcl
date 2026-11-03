######################################################################
# WALLY-debug-dcsr_ebreaku_debug_mode
# Rule dcsr_ebreaku_debug_mode: "ebreak instructions in U-mode enter
# Debug Mode."
#
# Resume in U-mode at an ebreak with dcsr.ebreaku=1 (the other
# ebreak bits clear). The ebreak must enter Debug Mode: the hart is
# halted with dcsr.cause=1, dcsr.prv=0, dpc = the ebreak, and no
# trap was taken (mcause unchanged, s11=0).
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
sd_run [lbl probe] 0 ebreaku
check_halted
check_rd $CSR_DCSR [expr {$DCSR_CAUSE | $DCSR_PRV}]
check_rd $CSR_DPC
check_rd $CSR_MCAUSE
check_rd [gpr s11]
sd_finish
