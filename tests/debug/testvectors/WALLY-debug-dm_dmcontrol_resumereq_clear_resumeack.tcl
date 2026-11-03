######################################################################
# WALLY-debug-dm_dmcontrol_resumereq_clear_resumeack
# Rule dm_dmcontrol_resumereq_clear_resumeack:
#   "It also clears the resume ack bit for those harts."
# Test: after a resume (resume ack = 1), writes resumereq=1 to the running
# hart: resume ack is cleared (and stays 0, as the running hart
# doesn't resume).
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
resume_hart
tv_check $DM_DMSTATUS $RESUMEACK_MASK $RESUMEACK_MASK
dmc_wr $RESUMEREQ
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $RESUMEACK_MASK 0

# Leave the test
halt_hart_twice
finish_test $objdump_file [xsize]
