######################################################################
# WALLY-debug-dm_access_register_aarpostincrement_enabled_optional
# Rule dm_access_register_aarpostincrement_enabled_optional:
# "Supporting this variant is optional."
#
# Wally does not support aarpostincrement=1 (optional), so a read of
# x25 with it set must fail with cmderr=2 (unsupported option).
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
cmd_wait [expr {(1 << 19) | [access_reg_cmd [gpr 25] $XSZ 0]}]
# Spec: "Supporting this variant is optional." + "If a command has
# unsupported options set ... the DM must set cmderr to 2". Wally
# does not implement it; Spike accepts it (and never increments).
check_cmderr 2

clear_cmderr
finish_test $objdump_file $XSZ
