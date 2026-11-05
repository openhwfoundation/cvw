######################################################################
# WALLY-debug-dm_dmcontrol_hartsello_op
# Rule dm_dmcontrol_hartsello_op:
#   "The low 10 bits of hartsel: the DM-specific index of the hart to
#   select. This hart is always part of the currently selected harts."
# Test: writes hartsello = all ones; it reads back the legal value 0
# (HARTSELLEN = 0), and that hart (0) is part of the selected harts:
# dmstatus shows it (exists, running) and haltreq with the same
# hartsel value halts it.
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

dmc_wr $HARTSELLO
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $HARTSELLO 0
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
dmc_wr [expr {$HALTREQ | $HARTSELLO}]
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
