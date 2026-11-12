######################################################################
# WALLY-debug-dm_quick_access_optional
# Rule dm_quick_access_optional: "Implementing this command is
# optional."
#
# Wally does not implement Quick Access (cmdtype 1): the command gives
# cmderr=2 with the hart running (Quick Access's precondition) and
# halted.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

cmd_wait [expr {1 << 24}]
check_cmderr
clear_cmderr
halt_hart
cmd_wait [expr {1 << 24}]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
