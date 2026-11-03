######################################################################
# WALLY-debug-dm_dmstatus_anyhalted_op
# Rule dm_dmstatus_anyhalted_op:
#   "This field is 1 when any currently selected hart is halted."
# Test: anyhalted is 0 while the selected hart runs, 1 while it is halted, 0
# after it resumes.
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
tv_check $DM_DMSTATUS $ANYHALTED 0
halt_hart
tv_check $DM_DMSTATUS $ANYHALTED $ANYHALTED
resume_hart
tv_check $DM_DMSTATUS $ANYHALTED 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
