######################################################################
# WALLY-debug-dm_command_cmdtype_enc
# Rule dm_command_cmdtype_enc: "cmdtype|Command === 0|Access Register
# Command¶1|Quick Access¶2|Access Memory Command ==="
#
# cmdtype 0 is Access Register (a read of x10 works); cmdtype 3
# encodes no command and is not supported (cmderr=2).
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
cmd_wait [access_reg_cmd [gpr 10] $XSZ 0]
check_cmderr
check_data $XSZ
cmd_wait [expr {3 << 24}]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
