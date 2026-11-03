######################################################################
# WALLY-debug-dm_hart_state_unavailable
# Rule dm_hart_state_unavailable:
#   "Harts are unavailable if they might exist/become available at a
#   later time, or if there are other harts with higher indexes than
#   this one."
# Test: the only hart is always available: allunavail = anyunavail = 0 while
# it runs, while halted, and after an ndmreset.
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

set M [expr {$ALLUNAVAIL | $ANYUNAVAIL}]
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $M 0
halt_hart
tv_check $DM_DMSTATUS $M 0
resume_hart
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $M 0
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
