######################################################################
# WALLY-debug-dm_sbcs_sbasize_op
# Rule dm_sbcs_sbasize_op: "Width of system bus addresses in bits. (0
# indicates there is no bus access support.)"
#
# sbcs.sbasize is 0: Wally has no system bus access.
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
tv_check $DM_SBCS 0xfe0
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
