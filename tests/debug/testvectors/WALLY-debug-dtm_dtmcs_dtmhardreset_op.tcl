######################################################################
# WALLY-debug-dtm_dtmcs_dtmhardreset_op
# Rule dtm_dtmcs_dtmhardreset_op: "Writing 1 to this bit does a
#   hard reset of the DTM, causing the DTM to forget about any
#   outstanding DMI transactions, and returning all registers and
#   internal state to their reset value."
# Leaves the result of a dmi read of data0 in dmi, writes
# dtmhardreset, then checks that dtmcs reads its reset value and
# that dmi captures its reset value (address 0, data 0, op 0: the
# Reset column of dmi).
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
dmi_scan $DM_DATA0 0x8badf00d 2
dmi_scan $DM_DATA0 0 1
dtmcs_write [expr {1 << 17}]
# dtmcs reset value: errinfo 4, dmistat 0, abits 7, version 1 (Wally
# implements errinfo; Spike's dtmcs is 0x71)
dtm_dr 32 0
dtm_check 0xffffffff $WALLY_DTMCS
# dmi reset value: address 0, data 0, op 0 (Spike: 0)
dtm_ir $IR_DMI
dmi_scan 0 0 0
dtm_check 0x1ffffffffff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
