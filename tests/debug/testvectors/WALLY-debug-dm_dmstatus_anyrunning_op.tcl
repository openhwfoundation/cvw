######################################################################
# WALLY-debug-dm_dmstatus_anyrunning_op
# Rule dm_dmstatus_anyrunning_op:
#   "This field is 1 when any currently selected hart is running."
# Test: anyrunning is 1 while the selected hart runs, 0 while it is halted,
# 1 after it resumes.
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
tv_check $DM_DMSTATUS $ANYRUNNING $ANYRUNNING
halt_hart
tv_check $DM_DMSTATUS $ANYRUNNING 0
resume_hart
tv_check $DM_DMSTATUS $ANYRUNNING $ANYRUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
