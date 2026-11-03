######################################################################
# WALLY-debug-dm_abstract_cmd_results_before_busy
# Rule dm_abstract_cmd_results_before_busy: "If a command returns
# results, the Debug Module must ensure they are placed in the data
# registers before busy is cleared."
#
# Reads x6; once busy reads 0, data0 (and data1 on RV64) already hold
# x6.
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
dmi_wr $DM_COMMAND [access_reg_cmd [gpr 6] $XSZ 0]
wait_abstract
tv_check $DM_ABSTRACTCS 0x1700
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
