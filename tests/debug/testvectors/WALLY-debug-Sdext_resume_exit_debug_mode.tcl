######################################################################
# WALLY-debug-Sdext_resume_exit_debug_mode
# Rule Sdext_resume_exit_debug_mode: "The hart is no longer in debug
# mode."
#
# Resume at probe in M-mode. probe reads dcsr, which is only
# accessible in Debug Mode, so it must trap (mcause=2), showing the
# hart left Debug Mode.
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
check_rd [gpr s2]
check_rd [gpr s3]
sd_finish
