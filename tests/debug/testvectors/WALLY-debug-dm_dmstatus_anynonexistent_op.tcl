######################################################################
# WALLY-debug-dm_dmstatus_anynonexistent_op
# Rule dm_dmstatus_anynonexistent_op:
#   "This field is 1 when any currently selected hart does not exist
#   in this hardware platform."
# Test: anynonexistent is 0 for the selected hart 0, which exists
# (hartsel=0, and hartsel written all ones, which HARTSELLEN=0
# legalizes to 0), running or halted.
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
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $ANYNONEXISTENT 0
dmc_wr [expr {$HARTSELLO | $HARTSELHI}]
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $ANYNONEXISTENT 0
dmc_wr 0
halt_hart
tv_check $DM_DMSTATUS $ANYNONEXISTENT 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
