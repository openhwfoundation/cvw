######################################################################
# WALLY-debug-dm_hartinfo_optional
# Rule dm_hartinfo_optional:
#   "This register is optional. If it is not present it should read
#   all-zero."
# Test: Wally does not implement hartinfo (no program buffer): it reads all-
# zero.
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

dmi_rd $DM_HARTINFO
# Wally has no hartinfo: "If it is not present it should read
# all-zero." Spike implements hartinfo.
tv_check $DM_HARTINFO 0xffffffff 0
halt_hart
dmi_rd $DM_HARTINFO
tv_check $DM_HARTINFO 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
