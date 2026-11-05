######################################################################
# WALLY-debug-dm_confstrptr3_acc
# Rule dm_confstrptr3_acc:
#   "This entire register is read-only."
# Test: reads confstrptr3, writes all ones to it, reads it again: unchanged
# (0: Wally does not implement the confstrptr registers;
# confstrptrvalid = 0).
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

# confstrptr3 is read-only. Wally does not implement it; DM
# registers that are unimplemented return 0 when read and ignore
# writes. Spike fails the accesses.
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $CONFSTRPTRVALID 0
dmi_rd_unimp [expr {$DM_CONFSTRPTR0 + 3}]
tv_check [expr {$DM_CONFSTRPTR0 + 3}] 0xffffffff 0
dmi_wr_unimp [expr {$DM_CONFSTRPTR0 + 3}] 0xffffffff
dmi_rd_unimp [expr {$DM_CONFSTRPTR0 + 3}]
tv_check [expr {$DM_CONFSTRPTR0 + 3}] 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
