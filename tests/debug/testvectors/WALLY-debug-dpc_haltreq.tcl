######################################################################
# WALLY-debug-dpc_haltreq
# Rule dpc_haltreq: "Address of the next instruction to be executed
# at the time that debug mode was entered."
#
# The hart runs a loop of non-idempotent instructions (addi,
# amoadd.w, lw/addi/sw, csrr/addi/csrw of mscratch, ecall whose
# handler counts) 3000 times, while the debugger halts and resumes
# it 12 times with haltreq. If dpc is the next instruction to
# execute at every halt, no instruction is skipped or repeated, so
# every counter ends at 3000 (s4=1). The body appears twice so
# consecutive ecalls trap at different PCs (the testbench watchdog
# flags 100 traps in a row at one PC).
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
sd_go [lbl loop_setup] 3 ebreakm
for {set i 0} {$i < 12} {incr i} {
    halt_hart
    rd $CSR_DPC
    resume_hart
}
sd_wait_halted 2000
check_rd [gpr s4]
sd_finish
