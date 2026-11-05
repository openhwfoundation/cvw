######################################################################
# WALLY-debug-dm_abstractcs_progbufsize_op
# Rule dm_abstractcs_progbufsize_op: "Size of the Program Buffer, in
# 32-bit words. Valid sizes are 0 - 16."
#
# abstractcs.progbufsize is a valid size (0-16): Wally has no program
# buffer (0).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dmi_rd $DM_ABSTRACTCS
tv_check $DM_ABSTRACTCS 0x1f000000
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
