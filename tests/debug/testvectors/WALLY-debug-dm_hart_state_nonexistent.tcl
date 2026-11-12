######################################################################
# WALLY-debug-dm_hart_state_nonexistent
# Rule dm_hart_state_nonexistent:
#   "Harts are nonexistent if they will never be part of this hardware
#   platform, no matter how long a user waits."
# Test: writes all ones to hartsel; Wally implements HARTSELLEN=0, so
# hartsel reads back 0 and the selected hart is hart 0, which exists:
# allnonexistent = anynonexistent = 0. (A single-hart DM with
# HARTSELLEN=0 cannot select a nonexistent hart.)
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
tv_check $DM_DMSTATUS [expr {$ALLNONEXISTENT | $ANYNONEXISTENT}] 0
dmc_wr 0
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS [expr {$ALLNONEXISTENT | $ANYNONEXISTENT}] 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
