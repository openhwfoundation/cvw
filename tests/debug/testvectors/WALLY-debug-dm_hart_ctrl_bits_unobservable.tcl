######################################################################
# WALLY-debug-dm_hart_ctrl_bits_unobservable
# Rule dm_hart_ctrl_bits_unobservable:
#   "The state of the other bits cannot be observed directly."
# Test: the halt request and halt-on-reset request bits cannot be read:
# after writing haltreq=1 and setresethaltreq=1, dmcontrol reads 0 in
# those fields.
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

# haltreq is WARZ ("When read this field returns 0"); Spike reads it
# back as 1.
dmc_wr $HALTREQ
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $HALTREQ 0
wait_halted
dmc_wr 0
set_resethaltreq
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL [expr {$SETRESETHALTREQ | $CLRRESETHALTREQ}] 0
clr_resethaltreq

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
