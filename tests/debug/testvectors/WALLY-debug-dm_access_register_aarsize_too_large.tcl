######################################################################
# WALLY-debug-dm_access_register_aarsize_too_large
# Rule dm_access_register_aarsize_too_large: "If aarsize specifies a
# size larger than the register's actual size, then the access must
# fail."
#
# aarsize larger than the register must fail: on RV32 aarsize=3
# (64-bit) for a GPR read, a GPR write (x22 must keep its value;
# signature) and a CSR read; on RV64 aarsize=4 (128-bit) for the same;
# on both aarsize=4 for an FPR (no Q). The rule only says the access
# must fail, so the test checks cmderr bit 1, which is set for cmderr
# 2 (not supported) and 3 (exception) alike.
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
set big [expr {$XSZ + 1}]
cmd_wait [access_reg_cmd [gpr 21] $big 0]
tv_check $DM_ABSTRACTCS 0x200
clear_cmderr
set_arg0 3 0xffffffffffffffff
cmd_wait [access_reg_cmd [gpr 22] $big 1]
tv_check $DM_ABSTRACTCS 0x200
clear_cmderr
cmd_wait [access_reg_cmd 0x340 $big 0]
tv_check $DM_ABSTRACTCS 0x200
clear_cmderr
cmd_wait [access_reg_cmd [fpr 14] 4 0]
tv_check $DM_ABSTRACTCS 0x200

clear_cmderr
finish_test $objdump_file $XSZ
