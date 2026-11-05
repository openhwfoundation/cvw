######################################################################
# WALLY-debug-dcsr_entry_update_writable
# Rule dcsr_entry_update_writable: "Upon entry into Debug Mode, v
# and prv are updated with the privilege level the hart was
# previously in, and cause is updated with the reason for Debug Mode
# entry. Other than these fields and nmip, the other fields of dcsr
# are only writable by the external debugger."
#
# Set ebreakm/s/u and resume in U-mode at an ebreak, then step an
# instruction in S-mode. On each entry the hart updates only prv and
# cause: the ebreak and step bits keep the debugger's values. From
# M-mode, a csrw to dcsr must trap (only the debugger writes it).
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

set mask [expr {$DCSR_EBREAKALL | $DCSR_STEP | $DCSR_CAUSE | $DCSR_PRV}]
sd_begin
sd_run [lbl u_code] 0 ebreakall
check_rd $CSR_DCSR $mask
sd_run [lbl s_code] 1 ebreakm ebreaku step
check_rd $CSR_DCSR $mask
sd_run [lbl m_code] 3 ebreakall
check_rd [gpr s3]
check_rd $CSR_DCSR $mask
sd_finish
