######################################################################
# WALLY-debug-dcsr_ebreaks_exception
# Rule dcsr_ebreaks_exception: "ebreak instructions in S-mode behave
# as described in the Privileged Spec."
#
# Resume in S-mode at an ebreak with dcsr.ebreaks=0 (the other
# ebreak bits set). The ebreak must raise a breakpoint exception:
# the handler records mcause=3, mepc = the ebreak, and mstatus.MPP =
# S; the hart then loops in S-mode until the debugger halts it.
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
sd_go [lbl probe] 1 ebreakm ebreaku
sleep 200
halt_hart
check_rd [gpr s9]
check_rd [gpr s8]
check_rd [gpr s7] $MSTATUS_MPP
check_rd [gpr s11]
sd_finish
