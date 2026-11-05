######################################################################
# WALLY-debug-dm_abstractcs_cmderr_none
# Rule dm_abstractcs_cmderr_none: "No error."
#
# cmderr is 0 (no error) after successful read and write commands.
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
cmd_wait [access_reg_cmd [gpr 7] $XSZ 0]
check_cmderr
cmd_wait [access_reg_cmd [gpr 7] $XSZ 1]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
