######################################################################
# WALLY-debug-dm_access_register_transfer_disabled
# Rule dm_access_register_transfer_disabled: "Don't do the operation
# specified by write."
#
# transfer=0 does not do the operation in write: write=1 leaves x27
# unchanged (read back; signature), write=0 leaves data unchanged.
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
set_arg0 3 0xffffffffffffffff
cmd_wait [access_reg_cmd [gpr 27] $XSZ 1 0]
check_cmderr
set_arg0 3 0x5555555555555555
cmd_wait [access_reg_cmd [gpr 27] $XSZ 0 0]
check_cmderr
check_data 3
cmd_wait [access_reg_cmd [gpr 27] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
