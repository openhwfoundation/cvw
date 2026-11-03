######################################################################
# WALLY-debug-dm_access_register_required
# Rule dm_access_register_required: "Debug Modules must implement this
# command and must support read and write access to all GPRs when the
# selected hart is halted."
#
# Reads all 32 GPRs, then writes every GPR (x0 too) with a new value
# and reads it back; the hart stores x1-x31 to the signature.
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
for {set n 0} {$n < 32} {incr n} {
    cmd_wait [access_reg_cmd [gpr $n] $XSZ 0]
    check_cmderr
    check_data $XSZ
}
for {set n 0} {$n < 32} {incr n} {
    set_arg0 $XSZ [expr {[gpr_val $n] ^ 0xf0f0f0f0f0f0f0f0}]
    cmd_wait [access_reg_cmd [gpr $n] $XSZ 1]
    check_cmderr
    set_arg0 $XSZ 0
    cmd_wait [access_reg_cmd [gpr $n] $XSZ 0]
    check_cmderr
    check_data $XSZ
}

clear_cmderr
finish_test $objdump_file $XSZ
