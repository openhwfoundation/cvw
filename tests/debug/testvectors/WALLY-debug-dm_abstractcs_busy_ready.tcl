######################################################################
# WALLY-debug-dm_abstractcs_busy_ready
# Rule dm_abstractcs_busy_ready: "There is no abstract command
# currently being executed."
#
# busy reads 0 when no abstract command is executing: before any
# command, and after a command has completed.
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
tv_check $DM_ABSTRACTCS 0x1000
halt_hart
cmd_wait [access_reg_cmd [gpr 3] $XSZ 0]
tv_check $DM_ABSTRACTCS 0x1000

clear_cmderr
finish_test $objdump_file $XSZ
