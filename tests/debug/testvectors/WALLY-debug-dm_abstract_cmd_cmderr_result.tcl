######################################################################
# WALLY-debug-dm_abstract_cmd_cmderr_result
# Rule dm_abstract_cmd_cmderr_result: "After completion, cmderr
# indicates whether the command was successful or not."
#
# A successful Access Register read leaves cmderr=0; a failing one
# (aarsize=4, 128 bits, larger than any GPR) leaves cmderr nonzero
# (2).
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
cmd_wait [access_reg_cmd [gpr 5] $XSZ 0]
check_cmderr
cmd_wait [access_reg_cmd [gpr 5] 4 0]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
