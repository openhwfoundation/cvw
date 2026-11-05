######################################################################
# WALLY-debug-dm_dmstatus_acc
# Rule dm_dmstatus_acc:
#   "This entire register is read-only."
# Test: reads dmstatus, writes all ones to it, and reads it again: unchanged
# (all bits compared; version and hasresethaltreq as Wally's spec
# values 3 and 1).
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

set v [dmi_rd $DM_DMSTATUS]
# Spike's dmstatus with the spec version (3; Spike reports 2) and
# hasresethaltreq (Wally implements it; Spike does not).
set want [expr {($v & ~0x2f) | 0x23}]
tv_check $DM_DMSTATUS 0xffffffff $want
dmi_wr_unimp $DM_DMSTATUS 0xffffffff
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS 0xffffffff $want

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
