######################################################################
# WALLY-debug-dm_access_register_cmdtype
# Rule dm_access_register_cmdtype: "This is 0 to indicate Access
# Register Command."
#
# A command word with cmdtype=0 is an Access Register command: reading
# x16 works.
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
cmd_wait [access_reg_cmd [gpr 16] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
