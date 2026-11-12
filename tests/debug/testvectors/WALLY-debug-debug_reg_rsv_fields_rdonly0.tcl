######################################################################
# WALLY-debug-debug_reg_rsv_fields_rdonly0
# Rule debug_reg_rsv_fields_rdonly0:
#   "Hardware must return 0 when those fields are read, and ignore the
#   value written to them."
# Test: writes all ones to dmstatus (read-only) and checks that the reserved
# fields of dmstatus (31:25, 21:20) read 0, with the hart running and
# halted.
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

set RSV [expr {(0x7f << 25) | (3 << 20)}]
dmi_wr_unimp $DM_DMSTATUS 0xffffffff
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $RSV 0
halt_hart
dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS $RSV 0

# Leave the test
halt_hart
finish_test $objdump_file [xsize]
