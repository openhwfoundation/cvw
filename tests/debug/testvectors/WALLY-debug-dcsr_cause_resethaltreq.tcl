######################################################################
# WALLY-debug-dcsr_cause_resethaltreq
# Rule dcsr_cause_resethaltreq: "The hart halted directly out of
# reset due to resethaltreq."
#
# Wally implements resethaltreq (dmstatus.hasresethaltreq=1). Set
# resethaltreq and pulse ndmreset; the hart halts out of reset.
# dcsr.cause must be 5 (3 is also allowed by the spec).
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
dmi_wr $DM_DMCONTROL 0x00000009
dmi_wr $DM_DMCONTROL 0x00000003
dmi_wr $DM_DMCONTROL 0x00000001
sleep 200
sd_wait_halted
# Spike has no resethaltreq: halt it now (no effect on a halted Wally).
halt_hart
dmi_wr $DM_DMCONTROL 0x10000005
# Spec: cause 5 "The hart halted directly out of reset due to
# resethaltreq." (3 is also acceptable; Wally reports 5.) Spike, which
# halted on the haltreq above, reports 3.
check_rd $CSR_DCSR $DCSR_CAUSE [expr {5 << 6}]
sd_finish
