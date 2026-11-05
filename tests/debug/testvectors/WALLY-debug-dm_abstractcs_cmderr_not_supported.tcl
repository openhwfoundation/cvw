######################################################################
# WALLY-debug-dm_abstractcs_cmderr_not_supported
# Rule dm_abstractcs_cmderr_not_supported: "The command in command is
# not supported. It may be supported with different options set, but
# it will not be supported at a later time when the hart or system
# state are different."
#
# An unsupported command (aarsize=4 read of x8) gives cmderr=2, and
# still does after the hart is resumed and halted again; Quick Access
# (unsupported) gives 2.
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
cmd_wait [access_reg_cmd [gpr 8] 4 0]
check_cmderr
clear_cmderr
resume_hart
halt_hart
cmd_wait [access_reg_cmd [gpr 8] 4 0]
check_cmderr
clear_cmderr
cmd_wait [expr {1 << 24}]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
