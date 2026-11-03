######################################################################
# WALLY-debug-dm_dmstatus_ndmresetpending_false
# Rule dm_dmstatus_ndmresetpending_false:
#   "Unimplemented, or ndmreset is zero and no ndmreset is currently
#   in progress."
# Test: ndmresetpending reads 0 before any ndmreset and after an ndmreset
# has been deasserted and completed.
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

dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $NDMRESETPENDING 0
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $NDMRESETPENDING 0
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
