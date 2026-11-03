######################################################################
# WALLY-debug-dm_abstractcs_cmderr_exception
# Rule dm_abstractcs_cmderr_exception: "An exception occurred while
# executing the command (e.g. while executing the Program Buffer)."
#
# Writing read-only CSRs (mvendorid 0xf11, cycle 0xc00) raises an
# exception in M-mode, so the commands end with cmderr=3.
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
set_arg0 3 0x1234
cmd_wait [access_reg_cmd 0xf11 $XSZ 1]
check_cmderr
clear_cmderr
cmd_wait [access_reg_cmd 0xc00 $XSZ 1]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
