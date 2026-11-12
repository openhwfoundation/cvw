######################################################################
# WALLY-debug-dm_dmstatus_stickyunavail_current
# Rule dm_dmstatus_stickyunavail_current:
#   "The per-hart unavail bits reflect the current state of the hart."
# Test: stickyunavail is 0, so anyunavail/allunavail give the current state:
# 0 for the available hart, running and halted.
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

set M [expr {$STICKYUNAVAIL | $ALLUNAVAIL | $ANYUNAVAIL}]
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $M 0
halt_hart
tv_check $DM_DMSTATUS $M 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
