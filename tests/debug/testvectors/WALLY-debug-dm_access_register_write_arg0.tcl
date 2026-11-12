######################################################################
# WALLY-debug-dm_access_register_write_arg0
# Rule dm_access_register_write_arg0: "Copy data from the specified
# register into arg0 portion of data."
#
# write=0 copies x29 into arg0 (data0, and data1 on RV64).
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
cmd_wait [access_reg_cmd [gpr 29] $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
