######################################################################
# WALLY-debug-dm_sbaddress2_optional
# Rule dm_sbaddress2_optional: "If sbasize is less than 65, then this
# register is not present."
#
# sbcs.sbasize is 0, so sbaddress2 (0x3b) is not present: it reads 0
# after a write.
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
dmi_wr 0x3b 0x87654321
dmi_rd 0x3b
# Spec: "If sbasize is less than 65, then this register is not present";
# unimplemented registers read 0. (Spike keeps the written value.)
tv_check 0x3b 0xffffffff 0
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
