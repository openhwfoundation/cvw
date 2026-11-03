######################################################################
# WALLY-debug-dm_access_register_aarsize_small_read
# Rule dm_access_register_aarsize_small_read: "If a register is
# accessible, then reads of aarsize less than or equal to the
# register's actual size must be supported."
#
# Reads with aarsize=2 (32 bits) of a 64-bit FPR (f14), of mscratch
# and of x23 are supported (cmderr=0) and return the low 32 bits.
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
foreach r [list [fpr 14] 0x340 [gpr 23]] {
    dmi_wr $DM_DATA0 0
    cmd_wait [access_reg_cmd $r 2 0]
    check_cmderr
    check_data 2
}

clear_cmderr
finish_test $objdump_file $XSZ
