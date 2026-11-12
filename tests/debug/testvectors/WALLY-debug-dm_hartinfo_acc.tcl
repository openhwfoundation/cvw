######################################################################
# WALLY-debug-dm_hartinfo_acc
# Rule dm_hartinfo_acc:
#   "This entire register is read-only."
# Test: reads hartinfo, writes all ones to it, reads it again: unchanged (0,
# as Wally does not implement hartinfo).
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

# Wally has no hartinfo, which then reads all-zero; Spike implements
# hartinfo (and fails the write).
dmi_rd $DM_HARTINFO
tv_check $DM_HARTINFO 0xffffffff 0
dmi_wr_unimp $DM_HARTINFO 0xffffffff
dmi_rd $DM_HARTINFO
tv_check $DM_HARTINFO 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
