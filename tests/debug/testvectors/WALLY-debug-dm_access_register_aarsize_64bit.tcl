######################################################################
# WALLY-debug-dm_access_register_aarsize_64bit
# Rule dm_access_register_aarsize_64bit: "Access the lowest 64 bits of
# the register."
#
# aarsize=3 reads and writes all 64 bits of a 64-bit register (x19/x20
# on RV64, f12/f13 on RV32 with D; f12 on both).
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
if {$ISA32} { set r1 [fpr 12]; set r2 [fpr 13] } else { set r1 [gpr 19]; set r2 [gpr 20] }
cmd_wait [access_reg_cmd $r1 3 0]
check_cmderr
check_data 3
cmd_wait [access_reg_cmd [fpr 12] 3 0]
check_cmderr
check_data 3
set_arg0 3 0x0f1e2d3c4b5a6978
cmd_wait [access_reg_cmd $r2 3 1]
check_cmderr
set_arg0 3 0
cmd_wait [access_reg_cmd $r2 3 0]
check_cmderr
check_data 3

clear_cmderr
finish_test $objdump_file $XSZ
