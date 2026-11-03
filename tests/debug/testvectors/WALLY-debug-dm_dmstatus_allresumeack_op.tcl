######################################################################
# WALLY-debug-dm_dmstatus_allresumeack_op
# Rule dm_dmstatus_allresumeack_op:
#   "This field is 1 when all currently selected harts have their
#   resume ack bit set."
# Test: allresumeack is 1 after the halted hart resumes, and 0 after
# resumereq is written to the running hart (resume ack cleared, no
# resume).
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
dmc_wr $RESUMEREQ
poll_until $DM_DMSTATUS $ALLRESUMEACK $ALLRESUMEACK
tv_check $DM_DMSTATUS $ALLRESUMEACK $ALLRESUMEACK
dmc_wr $RESUMEREQ
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $ALLRESUMEACK 0

# Leave the test
halt_hart_twice
finish_test $objdump_file [xsize]
