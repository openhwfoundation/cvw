######################################################################
# WALLY-debug-Sdext_wfi_halt
# Rule Sdext_wfi_halt: "If halt is requested while wfi is executing,
# then the hart must leave the stalled state, completing this
# instruction's execution, and then enter Debug Mode."
#
# Run M-mode code that executes wfi with no interrupt enabled, so
# the hart stalls in wfi. Request a halt. The wfi must complete: dpc
# = the instruction after the wfi. After resume, that instruction
# runs (s2=1) and the hart reaches the next ebreak.
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
sd_go [lbl m_code] 3 ebreakm
sleep 200
halt_hart
check_rd $CSR_DPC
resume_hart
sd_wait_halted
check_rd [gpr s2]
sd_finish
