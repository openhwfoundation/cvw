######################################################################
# WALLY-debug-Sdext_resume_prv_v
# Rule Sdext_resume_prv_v: "The current privilege mode and
# virtualization mode are changed to that specified by prv and v."
#
# Resume at probe with dcsr.prv = U, then S, then M. probe reads
# mstatus, which traps below M; the handler records mstatus (MPP =
# the mode the hart ran in) and counts the trap. Check the trap
# count, MPP, and dcsr.prv at the next halt for each mode.
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
foreach prv {0 1 3} {
    wr [gpr s7] 0
    wr [gpr s11] 0
    sd_run [lbl probe] $prv ebreakall
    check_rd [gpr s11]
    check_rd [gpr s7] $MSTATUS_MPP
    check_rd $CSR_DCSR $DCSR_PRV
}
sd_finish
