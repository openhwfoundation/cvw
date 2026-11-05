######################################################################
# WALLY-debug-dm_access_register_aarpostincrement_disabled
# Rule dm_access_register_aarpostincrement_disabled: "No effect. This
# variant must be supported."
#
# aarpostincrement=0 must be supported: two reads of x25 with it clear
# succeed and return x25.
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
for {set i 0} {$i < 2} {incr i} {
    set_arg0 3 0
    cmd_wait [access_reg_cmd [gpr 25] $XSZ 0]
    check_cmderr
    check_data $XSZ
}

clear_cmderr
finish_test $objdump_file $XSZ
