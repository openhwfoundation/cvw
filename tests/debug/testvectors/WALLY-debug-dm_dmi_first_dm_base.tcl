######################################################################
# WALLY-debug-dm_dmi_first_dm_base
# Rule dm_dmi_first_dm_base:
#   "The bottom of the address space is used for the first (and
#   usually only) DM."
# Test: the DM is the first DM, at DMI base 0: dmcontrol at 0x10 reads
# dmactive=1 and dmstatus at 0x11 reads a nonzero version (3).
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

dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $DMACTIVE 1
dmi_rd $DM_DMSTATUS
# dmstatus.version 3: "There is a Debug Module and it conforms to
# version 1.0 of this specification." (Spike reports 2.)
tv_check $DM_DMSTATUS 0xf 3

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
