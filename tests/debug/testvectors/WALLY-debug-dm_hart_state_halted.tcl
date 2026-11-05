######################################################################
# WALLY-debug-dm_hart_state_halted
# Rule dm_hart_state_halted:
#   "Harts are halted when they are in Debug Mode, only performing
#   tasks on behalf of the debugger."
# Test: the hart increments a0 in a loop. Halts it, sets a0 = 0 with an
# abstract command, waits (several DMI reads), and checks a0 is still
# 0: a halted hart does not run its program.
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
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
abs_write $REG_A0 [xsize] 0
for {set i 0} {$i < 8} {incr i} { dmi_rd $DM_DMSTATUS }
abs_read $REG_A0 [xsize]
tv_check $DM_DATA0 0xffffffff 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
