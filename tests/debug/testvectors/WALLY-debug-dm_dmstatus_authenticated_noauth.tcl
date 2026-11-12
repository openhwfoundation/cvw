######################################################################
# WALLY-debug-dm_dmstatus_authenticated_noauth
# Rule dm_dmstatus_authenticated_noauth:
#   "On components that don't implement authentication, this bit must
#   be preset as 1."
# Test: Wally implements no authentication: authenticated reads 1, also
# after a DM reset (it is preset).
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
tv_check $DM_DMSTATUS $AUTHENTICATED $AUTHENTICATED
dm_reset
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $AUTHENTICATED $AUTHENTICATED

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
