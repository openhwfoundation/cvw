######################################################################
# WALLY-debug-dm_dmi_reg_width
# Rule dm_dmi_reg_width:
#   "Each address points at a single 32-bit register that can be read
#   or written."
# Test: writes two complementary 32-bit patterns to data0 over the DMI and
# checks that all 32 bits read back.
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

dmi_wr $DM_DATA0 0xa5c33c5a
dmi_rd $DM_DATA0
tv_check $DM_DATA0 0xffffffff 0xa5c33c5a
dmi_wr $DM_DATA0 0x5a3cc3a5
dmi_rd $DM_DATA0
tv_check $DM_DATA0 0xffffffff 0x5a3cc3a5

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
