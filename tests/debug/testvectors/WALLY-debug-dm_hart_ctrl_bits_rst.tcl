######################################################################
# WALLY-debug-dm_hart_ctrl_bits_rst
# Rule dm_hart_ctrl_bits_rst:
#   "These 4 bits reset to 0, except for resume ack, which may reset
#   to either 0 or 1."
# Test: (1) sets resethaltreq, resets the DM (dmactive 0 then 1), pulses
# ndmreset: the hart runs (halt-on-reset bit reset to 0). (2) writes
# dmcontrol with haltreq=1 and dmactive=0, then reactivates the DM:
# the running hart stays running (halt request bit reset to 0).
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

set_resethaltreq
dm_reset
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
ack_havereset
dm_reset $HALTREQ
dmi_rd $DM_DMSTATUS
dmi_rd $DM_DMSTATUS
# "These 4 bits reset to 0": the halt request bit is 0 after the DM
# reset, so the running hart must not halt.
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
