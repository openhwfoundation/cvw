######################################################################
# WALLY-debug-dm_dmcontrol_hasel_single
# Rule dm_dmcontrol_hasel_single:
#   "There is a single currently selected hart, that is selected by
#   hartsel."
# Test: with hasel=0 the single selected hart is the one in hartsel (0):
# haltreq halts it and dmstatus shows exactly that hart halted.
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

dmc_wr 0
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$HASEL | $HARTSELLO | $HARTSELHI}] 0
dmc_wr $HALTREQ
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
