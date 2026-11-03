######################################################################
# WALLY-debug-dm_progbuf_count
# Rule dm_progbuf_count: "progbufsize indicates how many progbuf
# registers are implemented starting at progbuf0, counting up."
#
# progbufsize=0, so no progbuf register is implemented:
# progbuf0-progbuf15 read 0 after writes.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dmi_rd $DM_ABSTRACTCS
tv_check $DM_ABSTRACTCS 0x1f000000
for {set i 0} {$i < 16} {incr i} {
    set a [expr {$DM_PROGBUF0 + $i}]
    dmi_wr $a 0x00100073
    dmi_rd $a
    # Spec: unimplemented DM registers "return 0 when read. Writing them
    # has no effect." (Spike answers op=failed.)
    tv_check $a 0xffffffff 0
}
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
