######################################################################
# WALLY-debug-dm_dmactive_set_unobservable
# Rule dm_dmactive_set_unobservable:
#   "This in itself is not observable by any harts."
# Test: sets s1 = 0x5a5a5a5a in the running program, then resets the DM
# (dmactive 0 then 1) while the hart runs: the hart keeps running, is
# not reset (havereset 0), and s1 is unchanged.
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
abs_write $REG_S1 [xsize] 0x5a5a5a5a
resume_hart
dm_reset
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS [expr {$HARTSTATE_MASK | $HAVERESET_MASK}] $STATE_RUNNING
halt_hart
abs_read $REG_S1 [xsize]
tv_check $DM_DATA0 0xffffffff 0x5a5a5a5a

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
