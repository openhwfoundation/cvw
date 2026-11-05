######################################################################
# WALLY-debug-dm_access_register_transfer_disabled_ignore_size_regno
# Rule dm_access_register_transfer_disabled_ignore_size_regno: "This
# bit can be used to just execute the Program Buffer without having to
# worry about placing valid values into aarsize or regno."
#
# With transfer=0, aarsize and regno need not be valid: transfer=0
# commands with regno 0xbfff (no register), and with aarsize=7 (no
# size), succeed (cmderr=0).
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
cmd_wait [access_reg_cmd 0xbfff $XSZ 0 0]
check_cmderr
cmd_wait [access_reg_cmd [gpr 5] 7 0 0]
# Spec: transfer=0 "can be used to just execute the Program Buffer
# without having to worry about placing valid values into aarsize or
# regno". (Spike rejects aarsize=7 even without a transfer.)
check_cmderr 0
clear_cmderr
cmd_wait [access_reg_cmd 0xbfff 7 0 0]
check_cmderr 0

clear_cmderr
finish_test $objdump_file $XSZ
