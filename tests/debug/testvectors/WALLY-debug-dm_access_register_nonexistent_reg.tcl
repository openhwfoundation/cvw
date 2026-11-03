######################################################################
# WALLY-debug-dm_access_register_nonexistent_reg
# Rule dm_access_register_nonexistent_reg: "If the failure is that the
# requested register does not exist in the hart, cmderr must be set to
# 3 (exception)."
#
# Reads and writes CSR 0x600 (hstatus), which does not exist without
# the H extension: cmderr must be 3.
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
cmd_wait [access_reg_cmd 0x600 $XSZ 0]
check_cmderr
clear_cmderr
set_arg0 $XSZ 0
cmd_wait [access_reg_cmd 0x600 $XSZ 1]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
