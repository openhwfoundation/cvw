######################################################################
# WALLY-debug-dm_dmcontrol_resumereq_write1
# Rule dm_dmcontrol_resumereq_write1:
#   "Writing 1 causes the currently selected harts to resume once, if
#   they are halted when the write occurs."
# Test: halted hart, resumereq=1: it resumes (once) and keeps running.
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
dmc_wr $RESUMEREQ
wait_running
for {set i 0} {$i < 4} {incr i} { dmi_rd $DM_DMSTATUS }
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $RESUMEACK_MASK}] [expr {$STATE_RUNNING | $RESUMEACK_MASK}]

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
