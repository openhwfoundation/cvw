######################################################################
# WALLY-debug-dm_dmcontrol_hasel_rdonly0_no_mask
# Rule dm_dmcontrol_hasel_rdonly0_no_mask:
#   "An implementation which does not implement the hart array mask
#   register must tie this field to 0."
# Test: Wally implements no hart array mask register: hasel written 1 reads
# 0.
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

dmc_wr $HASEL
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $HASEL 0
dmc_wr 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
