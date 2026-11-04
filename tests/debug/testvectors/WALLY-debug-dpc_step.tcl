######################################################################
# WALLY-debug-dpc_step
# Rule dpc_step: "Address of the instruction that would be executed
# next if no debugging was going on"
#
# Step one instruction at a time and check dpc after each: addi
# (pc+4), not-taken bne (pc+4), taken beq (target), jal (target),
# jalr (target), c.addi (pc+2), mret (mepc), sret (sepc).
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
wr [gpr s6] [lbl st_jalr_tgt]
set ms [rd $CSR_MSTATUS]
wr $CSR_MSTATUS [expr {$ms | $MSTATUS_MPP}]
wr $CSR_MEPC [lbl mret_tgt]
sd_run [lbl st_addi] 3 ebreakall step
check_rd $CSR_DPC
for {set i 0} {$i < 6} {incr i} {
    resume_hart
    sd_wait_halted
    check_rd $CSR_DPC
}
wr 0x141 [lbl sret_tgt]
sd_run [lbl st_sret] 1 ebreakall step
check_rd $CSR_DPC
sd_finish
