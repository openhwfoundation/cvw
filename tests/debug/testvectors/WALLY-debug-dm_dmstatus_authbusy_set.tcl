######################################################################
# WALLY-debug-dm_dmstatus_authbusy_set
# Rule dm_dmstatus_authbusy_set:
#   "authbusy only becomes set in immediate response to an access to
#   authdata."
# Test: without any authdata access, authbusy stays 0 through halt, resume,
# ndmreset and a DM reset.
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
tv_check $DM_DMSTATUS $AUTHBUSY 0
halt_hart
tv_check $DM_DMSTATUS $AUTHBUSY 0
resume_hart
tv_check $DM_DMSTATUS $AUTHBUSY 0
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $AUTHBUSY 0
ack_havereset
dm_reset
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $AUTHBUSY 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
