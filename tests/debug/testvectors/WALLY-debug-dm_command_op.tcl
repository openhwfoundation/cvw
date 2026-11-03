######################################################################
# WALLY-debug-dm_command_op
# Rule dm_command_op: "Writes to this register cause the corresponding
# abstract command to be executed."
#
# Writing command executes it: a read of x9 lands in data.
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
set_arg0 3 0
cmd_wait [access_reg_cmd [gpr 9] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
