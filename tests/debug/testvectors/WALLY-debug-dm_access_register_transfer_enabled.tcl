######################################################################
# WALLY-debug-dm_access_register_transfer_enabled
# Rule dm_access_register_transfer_enabled: "Do the operation
# specified by write."
#
# transfer=1 does the operation in write: write x28, read it back (and
# signature).
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
set_arg0 $XSZ 0x2828282882828282
cmd_wait [access_reg_cmd [gpr 28] $XSZ 1]
check_cmderr
set_arg0 3 0
cmd_wait [access_reg_cmd [gpr 28] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
