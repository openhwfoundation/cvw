######################################################################
# WALLY-debug-dcsr_extcause_op
# Rule dcsr_extcause_op: "When cause is 7, this optional field
# contains the value of a more specific halt reason than "other."
# Otherwise it contains 0."
#
# Enter Debug Mode by haltreq (cause 3), ebreak (1) and step (4).
# extcause (dcsr[26:24]) must read 0 each time, because cause is not
# 7.
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
check_rd $CSR_DCSR 0x07000000
sd_run [lbl probe] 3 ebreakm
check_rd $CSR_DCSR 0x07000000
sd_run [lbl probe] 3 ebreakm step
check_rd $CSR_DCSR 0x07000000
sd_finish
