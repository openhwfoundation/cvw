######################################################################
# WALLY-debug-dm_sbcs_sbaccess64_op
# Rule dm_sbcs_sbaccess64_op: "1 when 64-bit system bus accesses are
# supported."
#
# sbcs.sbaccess64 is 0: Wally supports no 64-bit system bus accesses.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dmi_rd $DM_SBCS
tv_check $DM_SBCS 0x8
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
