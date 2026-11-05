######################################################################
# WALLY-debug-dm_dmstatus_version_1-0
# Rule dm_dmstatus_version_1-0: dmstatus.version = 3 means the DM
# conforms to version 1.0 of the debug spec.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS 0xf 3

halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
