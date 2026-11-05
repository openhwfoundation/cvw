######################################################################
# WALLY-debug-dm_nextdm_op
# Rule dm_nextdm_op:
#   "If there is more than one DM accessible on this DMI, this
#   register contains the base address of the next one in the chain,
#   or 0 if this is the last one in the chain."
# Test: reads nextdm (0x1d): 0, this being the last (only) DM.
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

# nextdm: "... or 0 if this is the last one in the chain." Spike
# fails the access (it does not implement nextdm).
dmi_rd_unimp $DM_NEXTDM
tv_check $DM_NEXTDM 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
