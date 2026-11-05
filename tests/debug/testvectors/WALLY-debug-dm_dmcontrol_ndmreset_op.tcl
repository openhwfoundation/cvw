######################################################################
# WALLY-debug-dm_dmcontrol_ndmreset_op
# Rule dm_dmcontrol_ndmreset_op:
#   "This bit controls the reset signal from the DM to the rest of the
#   hardware platform."
# Test: ndmreset is R/W (reads 1 while asserted, 0 after) and resets the
# platform: the hart reruns its entry code (s1 = 0x111 again after the
# debugger set it to 0x5a5a5a5a) and havereset is set.
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

halt_hart
abs_write $REG_S1 [xsize] 0x5a5a5a5a
resume_hart
dmc_wr $NDMRESET
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $NDMRESET $NDMRESET
dmc_wr 0
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $NDMRESET 0
wait_running
tv_check $DM_DMSTATUS $HAVERESET_MASK $HAVERESET_MASK
ack_havereset
halt_hart
abs_read $REG_S1 [xsize]
tv_check $DM_DATA0 0xffffffff 0x111

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
