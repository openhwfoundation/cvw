######################################################################
# WALLY-debug-dm_dmcontrol_hartreset_unimp
# Rule dm_dmcontrol_hartreset_unimp:
#   "If this feature is not implemented, the bit always stays 0"
# Test: Wally does not implement hartreset: after writing hartreset=1, the
# bit reads back 0.
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

dmc_wr $HARTRESET
dmi_rd $DM_DMCONTROL
# Wally doesn't implement hartreset (debug.sv HartReset = 0): "If
# this feature is not implemented, the bit always stays 0". Spike
# implements it (reads 1).
tv_check $DM_DMCONTROL $HARTRESET 0
dmc_wr 0
wait_running
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
