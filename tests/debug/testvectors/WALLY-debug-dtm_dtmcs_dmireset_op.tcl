######################################################################
# WALLY-debug-dtm_dtmcs_dmireset_op
# Rule dtm_dtmcs_dmireset_op: "Writing 1 to this bit clears the
#   sticky error state and resets errinfo, but does not affect
#   outstanding DMI transactions."
# Starts a dmi read of data0, writes dmireset, then collects the
# read: the result must survive (address 0x04, the data, op 0).
# errinfo must be back at its reset value 4 and the W1 bits read
# 0.
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
dmi_scan $DM_DATA0 0x0d15ea5e 2
dmi_scan $DM_DATA0 0 1
dtmcs_write [expr {1 << 16}]
# errinfo reset value 4 (Wally implements errinfo; Spike's reads 0, "not
# implemented"); dmireset/dtmhardreset are W1 and read 0
dtm_dr 32 0
dtm_check 0x1f0000 [expr {4 << 18}]
dtm_ir $IR_DMI
dmi_scan 0 0 0
dtm_check 0x1ffffffffff

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
