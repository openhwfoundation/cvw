######################################################################
# WALLY-debug-dm_sbdata3_optional
# Rule dm_sbdata3_optional: "This register only exists if sbaccess128
# is 1."
#
# The sbcs.sbaccess bits are 0, so sbdata3 (0x3f) is not present: it
# reads 0 after a write.
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
tv_check $DM_SBCS 0x10
dmi_wr 0x3f 0x87654321
dmi_rd 0x3f
# Spec: register not present when sbaccess128 is 0;
# unimplemented registers read 0. (Spike keeps the written value.)
tv_check 0x3f 0xffffffff 0
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
