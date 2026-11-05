######################################################################
# WALLY-debug-dm_abstractcs_cmderr_inhibit
# Rule dm_abstractcs_cmderr_inhibit: "No abstract command is started
# until the value is reset to 0."
#
# While cmderr=2, a read of x6 is not started (data keeps its pattern,
# cmderr stays 2); after cmderr is cleared the same command runs.
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
cmd_wait [access_reg_cmd [gpr 5] 4 0]
set_arg0 3 0x6666666699999999
cmd_wait [access_reg_cmd [gpr 6] $XSZ 0]
check_cmderr
check_data 3
clear_cmderr
cmd_wait [access_reg_cmd [gpr 6] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
