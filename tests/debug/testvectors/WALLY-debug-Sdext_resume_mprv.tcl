######################################################################
# WALLY-debug-Sdext_resume_mprv
# Rule Sdext_resume_mprv: "If the new privilege mode is less
# privileged than M-mode, MPRV in mstatus is cleared."
#
# Set mstatus.MPRV=1 while halted, then resume in U-mode and in
# S-mode. The first instruction is an ecall; the handler records
# mstatus, which must show MPRV=0 (cleared by the resume).
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
foreach prv {0 1} {
    set ms [rd $CSR_MSTATUS]
    wr $CSR_MSTATUS [expr {$ms | $MSTATUS_MPRV}]
    wr [gpr s7] -1
    sd_run [lbl probe] $prv ebreakall
    check_rd [gpr s7] $MSTATUS_MPRV
    check_rd [gpr s9]
}
sd_finish
