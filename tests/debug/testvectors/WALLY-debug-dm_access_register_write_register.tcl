######################################################################
# WALLY-debug-dm_access_register_write_register
# Rule dm_access_register_write_register: "Copy data from arg0 portion
# of data into the specified register."
#
# write=1 copies arg0 into x30 (read back; signature).
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
set_arg0 $XSZ 0x3030303003030303
cmd_wait [access_reg_cmd [gpr 30] $XSZ 1]
check_cmderr
set_arg0 3 0
cmd_wait [access_reg_cmd [gpr 30] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
