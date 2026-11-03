######################################################################
# WALLY-debug-dm_sbaddress3_optional
# Rule dm_sbaddress3_optional: "If sbasize is less than 97, then this
# register is not present."
#
# sbcs.sbasize is 0, so sbaddress3 (0x37) is not present: it reads 0
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
dmi_wr 0x37 0x87654321
dmi_rd 0x37
# Spec: "If sbasize is less than 97, then this register is not present";
# unimplemented registers read 0. (Spike keeps the written value.)
tv_check 0x37 0xffffffff 0
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
