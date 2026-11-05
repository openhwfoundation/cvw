######################################################################
# WALLY-debug-dm_command_cmderr_ignore
# Rule dm_command_cmderr_ignore: "If cmderr is non-zero, writes to
# this register are ignored."
#
# While cmderr=2, a write of x10 is ignored (x10 read back after
# clearing cmderr; signature).
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
cmd_wait [access_reg_cmd [gpr 10] 4 0]
set_arg0 3 0xdeaddeaddeaddead
cmd_wait [access_reg_cmd [gpr 10] $XSZ 1]
check_cmderr
clear_cmderr
set_arg0 3 0
cmd_wait [access_reg_cmd [gpr 10] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
