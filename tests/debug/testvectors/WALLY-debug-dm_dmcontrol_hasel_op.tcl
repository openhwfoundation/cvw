######################################################################
# WALLY-debug-dm_dmcontrol_hasel_op
# Rule dm_dmcontrol_hasel_op:
#   "Selects the definition of currently selected harts."
# Test: Wally has no hart array mask: writing hasel=1 with haltreq selects
# just the hartsel hart (hart 0), which halts, and hasel reads 0.
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

dmc_wr [expr {$HASEL | $HALTREQ}]
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $HASEL 0
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
