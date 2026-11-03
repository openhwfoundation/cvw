######################################################################
# WALLY-debug-dm_dmcontrol_haltreq_write0
# Rule dm_dmcontrol_haltreq_write0:
#   "Writing 0 clears the halt request bit for all currently selected
#   harts. This may cancel outstanding halt requests for those harts."
# Test: halts the hart with haltreq=1 left set, writes haltreq=0, then
# resumes: the hart stays running (its halt request bit was cleared;
# with it set the hart would halt again).
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
dmc_wr 0
dmc_wr $RESUMEREQ
wait_running
for {set i 0} {$i < 4} {incr i} { dmi_rd $DM_DMSTATUS }
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
