######################################################################
# WALLY-debug-dm_abstractcs_cmderr_set
# Rule dm_abstractcs_cmderr_set: "Gets set if an abstract command
# fails."
#
# cmderr is 0 before, and set after failing commands: a read of absent
# CSR 0x600 (3) and an aarsize=4 read (2).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dmi_rd $DM_ABSTRACTCS
check_cmderr
halt_hart
cmd_wait [access_reg_cmd 0x600 $XSZ 0]
check_cmderr
clear_cmderr
cmd_wait [access_reg_cmd [gpr 4] 4 0]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
