######################################################################
# WALLY-debug-dm_access_register_core_debug_regs
# Rule dm_access_register_core_debug_regs: "The Core Debug Registers
# (xref:debreg[]) should be accessible if abstract CSR access is
# implemented."
#
# (Recommendation) dcsr and dpc are accessible through Access
# Register: read dcsr (cmderr only), read dpc (= park), write dpc and
# read it back.
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
cmd_wait [access_reg_cmd 0x7b0 $XSZ 0]
check_cmderr
cmd_wait [access_reg_cmd 0x7b1 $XSZ 0]
check_cmderr
check_data $XSZ
set_arg0 $XSZ [get_address $objdump_file test_end]
cmd_wait [access_reg_cmd 0x7b1 $XSZ 1]
check_cmderr
set_arg0 $XSZ 0
cmd_wait [access_reg_cmd 0x7b1 $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
