######################################################################
# WALLY-debug-dcsr_prv_entry
# Rule dcsr_prv_entry: "Contains the privilege mode the hart was
# operating in when Debug Mode was entered. The encoding is
# described in <<tab:privmode>>."
#
# Enter Debug Mode from each privilege mode and check dcsr.prv:
# ebreak in M, S and U (3, 1, 0); a step over mret with MPP=U (0,
# the mode after the mret); a step over a U-mode ecall (3, the
# handler's mode).
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
foreach prv {3 1 0} {
    sd_run [lbl probe] $prv ebreakall
    check_rd $CSR_DCSR $DCSR_PRV
}
set ms [rd $CSR_MSTATUS]
wr $CSR_MSTATUS [expr {$ms & ~$MSTATUS_MPP}]
wr $CSR_MEPC [lbl probe]
sd_run [lbl m_mret] 3 ebreakall step
check_rd $CSR_DCSR $DCSR_PRV
sd_run [lbl u_ecall] 0 ebreakall step
check_rd $CSR_DCSR $DCSR_PRV
sd_finish
