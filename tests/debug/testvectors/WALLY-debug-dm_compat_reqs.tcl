######################################################################
# WALLY-debug-dm_compat_reqs
# Rule dm_compat_reqs:
#   "The Debug Module implements a translation interface between
#   abstract debug operations and their specific implementation. It
#   might support the following operations: Give the debugger
#   necessary information about the implementation. (Required) Allow
#   any individual hart to be halted and resumed. ..."
# Test: exercises the required DM operations on the hart: halt it and see it
# halted, write and read a GPR with abstract commands, resume it and
# see it running.
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

dmc_wr $HALTREQ
wait_halted
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
dmc_wr 0
abs_write $REG_S1 [xsize] 0x1234abcd
abs_read $REG_S1 [xsize]
tv_check $DM_DATA0 0xffffffff 0x1234abcd
dmc_wr $RESUMEREQ
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
