######################################################################
# WALLY-debug-dtm_dmi_op_wr_write
# Rule dtm_dmi_op_wr_write: "2 (write): Write data to address."
# A raw dmi write of data1, read back with an ordinary DMI read
# (OpenOCD's riscv dmi_read), must return the written value.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dtm_ir $IR_DMI
dmi_scan $DM_DATA1 0x5555aaaa 2
dmi_scan 0 0 0
dmi_rd $DM_DATA1
tv_check $DM_DATA1 0xffffffff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
