######################################################################
# WALLY-debug-dm_reg_unimplemented
# Rule dm_reg_unimplemented: "Debug Module DMI Registers that are
# unimplemented or not mentioned in the table below return 0 when
# read. Writing them has no effect."
#
# DMI addresses not in the DM register table (0x00-0x03, 0x1e, 0x31,
# 0x33, 0x36, 0x41, 0x50, 0x6f) read 0 after writing all ones.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

foreach a {0x00 0x01 0x02 0x03 0x1e 0x31 0x33 0x36 0x41 0x50 0x6f} {
    dmi_wr $a 0xffffffff
    dmi_rd $a
    # Spec: registers "not mentioned in the table below return 0 when
    # read." (Spike answers op=failed.)
    tv_check $a 0xffffffff 0
}
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
