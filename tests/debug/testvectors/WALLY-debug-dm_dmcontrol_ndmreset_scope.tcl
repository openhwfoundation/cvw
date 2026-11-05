######################################################################
# WALLY-debug-dm_dmcontrol_ndmreset_scope
# Rule dm_dmcontrol_ndmreset_scope:
#   "The signal should reset every part of the hardware platform,
#   including every hart, except for the DM and any logic required to
#   access the DM."
# Test: ndmreset resets the hart (havereset set; entry code reruns: s1 =
# 0x111 again) but not the DM: dmactive stays 1 and data0 keeps its
# value.
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
dmi_wr $DM_DATA0 0x2468ace0
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HAVERESET_MASK $HAVERESET_MASK
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $DMACTIVE 1
dmi_rd $DM_DATA0
tv_check $DM_DATA0 0xffffffff 0x2468ace0
ack_havereset
halt_hart
abs_read $REG_S1 [xsize]
tv_check $DM_DATA0 0xffffffff 0x111

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
