######################################################################
# WALLY-debug-dm_access_register_regno
# Rule dm_access_register_regno: "Number of the register to access, as
# described in xref:tab:regno[]."
#
# regno selects the register: reads of x1, x2 and f17 return each
# one's value.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

halt_hart
foreach {r sz} [list [gpr 1] $XSZ [gpr 2] $XSZ [fpr 17] 3] {
    set_arg0 3 0
    cmd_wait [access_reg_cmd $r $sz 0]
    check_cmderr
    check_data $sz
}

clear_cmderr
finish_test $objdump_file $XSZ
