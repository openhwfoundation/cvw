######################################################################
# WALLY-debug-dm_dmstatus_version_readable
# Rule dm_dmstatus_version_readable:
#   "For forward compatibility, version will always be readable when
#   bit 1 (ndmreset) is 0 and bit 0 (dmactive) is 1."
# Test: with ndmreset=0 and dmactive=1, version reads 3: at the start, after
# a DM reset, and after an ndmreset.
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

# dmstatus.version 3 (1.0); Spike reports 2.
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS 0xf 3
dm_reset
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS 0xf 3
ndmreset_pulse
wait_running
tv_check $DM_DMSTATUS 0xf 3
ack_havereset

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
