######################################################################
# WALLY-debug-dm_abstract_cmd_data_lsw
# Rule dm_abstract_cmd_data_lsw: "In all cases the least-significant
# word is placed in the lowest-numbered data register."
#
# 64-bit Access Register read and write (GPR on RV64, FPR on RV32 with
# D): the least-significant word is in data0, the most-significant in
# data1.
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
if {$ISA32} { set r1 [fpr 3]; set r2 [fpr 4] } else { set r1 [gpr 7]; set r2 [gpr 8] }
cmd_wait [access_reg_cmd $r1 3 0]
check_cmderr
check_data 3
# Write data1:data0 = 0x01234567:0x89abcdef, read it back.
set_arg0 3 0x0123456789abcdef
cmd_wait [access_reg_cmd $r2 3 1]
check_cmderr
set_arg0 3 0
cmd_wait [access_reg_cmd $r2 3 0]
check_cmderr
check_data 3

clear_cmderr
finish_test $objdump_file $XSZ
