######################################################################
# WALLY-debug-dm_hart_state_list
# Rule dm_hart_state_list:
#   "Every hart that can be selected is in exactly one of the
#   following four DM states: non-existent, unavailable, running, or
#   halted."
# Test: checks that dmstatus bits 15:8 show exactly one state for the
# selected hart: running (allrunning, anyrunning) while it runs,
# halted (allhalted, anyhalted) while halted, and running again after
# resume.
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

dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
halt_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
resume_hart
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
