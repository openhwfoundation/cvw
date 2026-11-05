######################################################################
# WALLY-debug-dm_halt_request_ignored_halted
# Rule dm_halt_request_ignored_halted:
#   "Halted harts ignore their halt request bit."
# Test: halts the hart, sets dpc to a marker, writes haltreq=1 again while
# it is halted, and checks the hart stayed halted with dpc unchanged
# (no second halt entry).
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

set mark [get_address $objdump_file park]
halt_hart
abs_write $REG_DPC [xsize] $mark
dmc_wr $HALTREQ
dmi_rd $DM_DMSTATUS
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_HALTED
abs_read $REG_DPC [xsize]
tv_check $DM_DATA0 0xffffffff $mark
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
