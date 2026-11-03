######################################################################
# WALLY-debug-dm_access_register_group_support
# Rule dm_access_register_group_support: "It is recommended that if
# one register in a group is accessible, then all registers in that
# group are accessible, but each individual register (aside from GPRs)
# may be supported differently across read, write, and halt status."
#
# (Recommendation) All 32 FPRs are accessible: reads every FPR with
# aarsize=3.
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
    cmd_wait [access_reg_cmd [fpr $n] 3 0]
    check_cmderr
    check_data 3
}

clear_cmderr
finish_test $objdump_file $XSZ
