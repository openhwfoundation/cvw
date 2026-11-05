######################################################################
# WALLY-debug-dm_data_op
# Rule dm_data_op: "data0 through data11 are registers that may be
# read or changed by abstract commands. datacount indicates how many
# of them are implemented, starting at data0, counting up."
#
# datacount data registers starting at data0 are implemented: data0
# and data1 hold written values; data2-data11 (beyond datacount=2) are
# not implemented and read 0 after a write.
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
tv_check $DM_ABSTRACTCS 0xf
for {set i 0} {$i < 12} {incr i} {
    set a [expr {$DM_DATA0 + $i}]
    dmi_wr $a [expr {0x11111111 * ($i + 1)}]
    dmi_rd $a
    if {$i < 2} {
        tv_check $a 0xffffffff
    } else {
        # Spec: unimplemented DM registers "return 0 when read. Writing
        # them has no effect." (Spike answers op=failed.)
        tv_check $a 0xffffffff 0
    }
}
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
