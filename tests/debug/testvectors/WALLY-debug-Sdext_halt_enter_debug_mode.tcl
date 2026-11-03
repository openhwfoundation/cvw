######################################################################
# WALLY-debug-Sdext_halt_enter_debug_mode
# Rule Sdext_halt_enter_debug_mode: "The hart enters Debug Mode."
#
# Request a halt while the hart runs its park loop. The hart must
# enter Debug Mode: dmstatus reports it halted, and dcsr (a Debug
# Mode CSR) can be read (cmderr=0).
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

dmi_wr $DM_DMCONTROL 0x80000001
sd_wait_halted
dmi_wr $DM_DMCONTROL 0x00000001
check_halted
rd $CSR_DCSR
check_cmderr
sd_finish
