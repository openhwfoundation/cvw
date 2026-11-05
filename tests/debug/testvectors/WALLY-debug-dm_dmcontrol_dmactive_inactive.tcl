######################################################################
# WALLY-debug-dm_dmcontrol_dmactive_inactive
# Rule dm_dmcontrol_dmactive_inactive:
#   "The module's state, including authentication mechanism, takes its
#   reset values (the dmactive bit is the only bit which can be
#   written to something other than its reset value)."
# Test: (1) with the hart running, writes dmcontrol = haltreq|dmactive=0,
# then reactivates the DM: the halt request bit has its reset value 0,
# so the hart is still running. (2) writes dmcontrol =
# ndmreset|dmactive=0, then reactivates: ndmreset reads its reset
# value 0.
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

dm_reset $HALTREQ
for {set i 0} {$i < 4} {incr i} { dmi_rd $DM_DMSTATUS }
# dmactive=0: "The module's state ... takes its reset values (the
# dmactive bit is the only bit which can be written to something
# other than its reset value)". The halt request bit resets to 0.
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
dmc_wr 0
dm_reset $NDMRESET
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$NDMRESET | $DMACTIVE}] $DMACTIVE
dmc_wr 0
wait_running
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
