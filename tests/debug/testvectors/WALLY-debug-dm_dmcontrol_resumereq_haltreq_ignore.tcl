######################################################################
# WALLY-debug-dm_dmcontrol_resumereq_haltreq_ignore
# Rule dm_dmcontrol_resumereq_haltreq_ignore:
#   "resumereq is ignored if haltreq is set."
# Test: halted hart with resume ack = 1: writes haltreq=1 and resumereq=1
# together. resumereq is ignored: the hart stays halted and resume ack
# is not cleared.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
# No servers: concurrent generations would collide on their ports
gdb port disabled
telnet port disabled
tcl port disabled
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmrun.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

halt_hart
resume_hart
halt_hart
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_HALTED | $RESUMEACK_MASK}]
dmc_wr [expr {$HALTREQ | $RESUMEREQ}]
for {set i 0} {$i < 4} {incr i} { dmi_rd $DM_DMSTATUS }
# "resumereq is ignored if haltreq is set": no resume, and resume
# ack is not cleared.
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_HALTED | $RESUMEACK_MASK}]
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
