######################################################################
# WALLY-debug-dm_dmcontrol_hartsellen
# Rule dm_dmcontrol_hartsellen:
#   "While the spec allows for 20 hartsel bits, an implementation may
#   choose to implement fewer than that. The actual width of hartsel
#   is called HARTSELLEN. It must be at least 0 and at most 20."
# Test: writes all ones to hartsel and reads it back: 0, i.e. HARTSELLEN = 0
# (within 0..20). Consistently, dmstatus then shows hart 0 (exists,
# running), and haltreq with hartsel all ones halts hart 0.
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

dmc_wr [expr {$HARTSELLO | $HARTSELHI}]
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$HARTSELLO | $HARTSELHI}] 0
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
dmc_wr [expr {$HALTREQ | $HARTSELLO | $HARTSELHI}]
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
