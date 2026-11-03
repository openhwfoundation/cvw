######################################################################
# WALLY-debug-dm_hart_reset_supported_ops
# Rule dm_hart_reset_supported_ops:
#   "While ndmreset or any external reset is asserted, the only
#   supported DM operations are reading/writing dmcontrol and reading
#   ndmresetpending. The behavior of other accesses is undefined."
# Test: while ndmreset is asserted, reads dmcontrol (ndmreset and dmactive
# read 1) and writes dmcontrol to deassert ndmreset (reads 0
# afterwards).
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

dmc_wr $NDMRESET
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$NDMRESET | $DMACTIVE}] 3
dmc_wr 0
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$NDMRESET | $DMACTIVE}] 1
wait_running
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
