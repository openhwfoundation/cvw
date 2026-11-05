######################################################################
# WALLY-debug-dm_access_memory_optional
# Rule dm_access_memory_optional: "Debug Modules may optionally
# implement this command and may support read and write access to
# memory locations when the selected hart is running or halted."
#
# Wally does not implement Access Memory (cmdtype 2): a 32-bit read
# gives cmderr=2.
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
set a [get_address $objdump_file fpr_init]
set_arg0 3 $a
cmd_wait [expr {(2 << 24) | (2 << 20)}]
# Spec: "Debug Modules may optionally implement this command", and an
# unsupported command gives cmderr 2. Wally does not implement it;
# Spike does.
check_cmderr 2

clear_cmderr
finish_test $objdump_file $XSZ
