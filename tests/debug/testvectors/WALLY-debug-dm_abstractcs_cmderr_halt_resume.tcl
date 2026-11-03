######################################################################
# WALLY-debug-dm_abstractcs_cmderr_halt_resume
# Rule dm_abstractcs_cmderr_halt_resume: "The abstract command
# couldn't execute because the hart wasn't in the required state
# (running/halted), or unavailable."
#
# Access Register read and write of x9 while the hart is running give
# cmderr=4 (x9 unchanged: signature).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

cmd_wait [access_reg_cmd [gpr 9] $XSZ 0]
check_cmderr
clear_cmderr
set_arg0 3 0
cmd_wait [access_reg_cmd [gpr 9] $XSZ 1]
check_cmderr
clear_cmderr
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
