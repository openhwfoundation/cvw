######################################################################
# WALLY-debug-dm_abstractcs_datacount_op
# Rule dm_abstractcs_datacount_op: "Number of data registers that are
# implemented as part of the abstract command interface. Valid sizes
# are 1 -- 12."
#
# abstractcs.datacount is a valid count (1-12), and at least 2 on
# Wally (its abstract register arguments are up to 64 bits wide on
# RV64 and RV32-with-D).
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
tv_check $DM_ABSTRACTCS 0xf
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
