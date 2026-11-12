######################################################################
# WALLY-debug-dm_hart_index_contiguous
# Rule dm_hart_index_contiguous:
#   "Hart indexes start at 0 and are contiguous until the final
#   index."
# Test: hart indexes start at 0: with hartsel=0 the selected hart exists
# (allnonexistent = anynonexistent = 0) and is running.
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

dmc_wr 0
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $HARTSTATE_MASK $STATE_RUNNING

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
