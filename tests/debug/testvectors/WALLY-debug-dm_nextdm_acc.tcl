######################################################################
# WALLY-debug-dm_nextdm_acc
# Rule dm_nextdm_acc:
#   "This entire register is read-only."
# Test: reads nextdm, writes all ones to it, and checks it still reads the
# same value (0).
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

# nextdm is read-only and reads 0 on a single-DM DMI. Spike fails
# the accesses (it does not implement nextdm).
dmi_rd_unimp $DM_NEXTDM
tv_check $DM_NEXTDM 0xffffffff 0
dmi_wr_unimp $DM_NEXTDM 0xffffffff
dmi_rd_unimp $DM_NEXTDM
tv_check $DM_NEXTDM 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
