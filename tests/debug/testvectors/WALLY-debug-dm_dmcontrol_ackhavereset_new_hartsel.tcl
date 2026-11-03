######################################################################
# WALLY-debug-dm_dmcontrol_ackhavereset_new_hartsel
# Rule dm_dmcontrol_ackhavereset_new_hartsel:
#   "Writes apply to the new value of hartsel and hasel."
# Test: after an ndmreset, writes ackhavereset=1 together with hartsel = all
# ones (legalized to 0): it applies to hart 0, whose havereset clears.
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

ndmreset_pulse
wait_running
dmc_wr [expr {$ACKHAVERESET | $HARTSELLO | $HARTSELHI}]
dmc_wr 0
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HAVERESET_MASK 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
