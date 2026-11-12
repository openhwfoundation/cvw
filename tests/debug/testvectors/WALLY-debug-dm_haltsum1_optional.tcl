######################################################################
# WALLY-debug-dm_haltsum1_optional
# Rule dm_haltsum1_optional:
#   "This register might not be present if fewer than 33 harts are
#   connected to this DM."
# Test: haltsum1 may be absent with fewer than 33 harts; Wally (1 hart)
# omits it, so it reads 0 (an unimplemented DM register) even with the
# hart halted, and ignores writes.
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
# Wally omits haltsum1: "DM registers that are unimplemented ...
# return 0 when read. Writing them has no effect." Spike fails the
# accesses.
dmi_rd_unimp $DM_HALTSUM1
tv_check $DM_HALTSUM1 0xffffffff 0
dmi_wr_unimp $DM_HALTSUM1 0xffffffff
dmi_rd_unimp $DM_HALTSUM1
tv_check $DM_HALTSUM1 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
