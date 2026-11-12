######################################################################
# WALLY-debug-dm_access_register_aarsize_32bit
# Rule dm_access_register_aarsize_32bit: "Access the lowest 32 bits of
# the register."
#
# aarsize=2 reads the low 32 bits of x17 and of f11, and writes the
# low 32 bits of x18 (read back with aarsize=2; the high bits are
# UNSPECIFIED, so x18 is restored with a full-width write before the
# signature is taken).
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
cmd_wait [access_reg_cmd [gpr 17] 2 0]
check_cmderr
check_data 2
cmd_wait [access_reg_cmd [fpr 11] 2 0]
check_cmderr
check_data 2
set_arg0 2 0x13579bdf
cmd_wait [access_reg_cmd [gpr 18] 2 1]
check_cmderr
set_arg0 2 0
cmd_wait [access_reg_cmd [gpr 18] 2 0]
check_cmderr
check_data 2
set_arg0 $XSZ [gpr_val 18]
cmd_wait [access_reg_cmd [gpr 18] $XSZ 1]

clear_cmderr
finish_test $objdump_file $XSZ
