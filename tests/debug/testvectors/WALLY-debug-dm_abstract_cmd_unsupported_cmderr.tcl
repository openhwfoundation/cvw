######################################################################
# WALLY-debug-dm_abstract_cmd_unsupported_cmderr
# Rule dm_abstract_cmd_unsupported_cmderr: "If a command has
# unsupported options set or if bits that are defined as 0 aren't 0,
# then the DM must set cmderr to 2 (not supported)."
#
# Sets bit 23 (defined as 0) of an otherwise valid Access Register
# read, then writes an undefined cmdtype (0xff); both must give
# cmderr=2.
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
# Bit 23 of Access Register is defined as 0.
cmd_wait [expr {(1 << 23) | [access_reg_cmd [gpr 5] $XSZ 0]}]
# Spec: "if bits that are defined as 0 aren't 0, then the DM must set
# cmderr to 2 (not supported)." (Spike ignores bit 23.)
check_cmderr 2
clear_cmderr
# cmdtype 0xff is no defined command: unsupported.
cmd_wait [expr {0xff << 24}]
check_cmderr

clear_cmderr
finish_test $objdump_file $XSZ
