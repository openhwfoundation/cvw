######################################################################
# WALLY-debug-dm_dmstatus_authbusy_ready
# Rule dm_dmstatus_authbusy_ready:
#   "The authentication module is ready to process the next read/write
#   to authdata."
# Test: authbusy reads 0 (the authentication module is always ready; there
# is no authentication).
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

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
