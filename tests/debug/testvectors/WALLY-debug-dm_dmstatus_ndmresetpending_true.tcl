######################################################################
# WALLY-debug-dm_dmstatus_ndmresetpending_true
# Rule dm_dmstatus_ndmresetpending_true:
#   "ndmreset is currently nonzero, or there is an ndmreset in
#   progress."
# Test: while ndmreset is 1, ndmresetpending reads 1 (Wally implements
# ndmresetpending).
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
dmi_rd $DM_DMSTATUS
# Wally implements ndmresetpending (debug.sv NDMResetPending); then
# "1 (true): ndmreset is currently nonzero". Spike doesn't implement
# it (reads 0, allowed for an unimplemented field).
tv_check $DM_DMSTATUS $NDMRESETPENDING $NDMRESETPENDING
dmc_wr 0
wait_running
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
