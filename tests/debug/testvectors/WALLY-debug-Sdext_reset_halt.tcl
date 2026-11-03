######################################################################
# WALLY-debug-Sdext_reset_halt
# Rule Sdext_reset_halt: "If the halt signal (driven by the hart's
# halt request bit in the Debug Module) or resethaltreq are asserted
# when a hart comes out of reset, the hart must enter Debug Mode
# before executing any instructions, but after performing any
# initialization that would usually happen before the first
# instruction is executed."
#
# Phase 1: hold dmcontrol.haltreq while pulsing ndmreset. Phase 2:
# set resethaltreq and pulse ndmreset. Each time the hart must halt
# before executing any instruction, so dpc = the reset vector
# (0x80000000 on Wally).
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
# Phase 1: haltreq held across ndmreset
dmi_wr $DM_DMCONTROL 0x80000003
dmi_wr $DM_DMCONTROL 0x80000001
sd_wait_halted
dmi_wr $DM_DMCONTROL 0x10000001
# Spec: "the hart must enter Debug Mode before executing any
# instructions", so dpc is the first instruction: Wally's reset vector
# 0x80000000. Spike starts at its boot ROM (0x1000) instead.
check_rd $CSR_DPC -1 0x80000000
# Phase 2: resethaltreq set, then ndmreset
dmi_wr $DM_DMCONTROL 0x00000009
dmi_wr $DM_DMCONTROL 0x00000003
dmi_wr $DM_DMCONTROL 0x00000001
sleep 200
sd_wait_halted
# Spike has no resethaltreq (hasresethaltreq=0): halt it now. Wally is
# already halted, so this haltreq has no effect there.
halt_hart
dmi_wr $DM_DMCONTROL 0x10000005
# Spec: "If ... resethaltreq [is] asserted when a hart comes out of
# reset, the hart must enter Debug Mode before executing any
# instructions": dpc = reset vector 0x80000000.
check_rd $CSR_DPC -1 0x80000000
sd_finish
