######################################################################
# WALLY-debug-dtm_jtag_ir_enc
# Rule dtm_jtag_ir_enc: "Table of JTAG DTM TAP registers: 0x00
#   bypass, 0x01 idcode, 0x10 dtmcs, 0x11 dmi, 0x12-0x17 reserved
#   (bypass), 0x1f bypass."
# Scans each listed IR encoding and checks that it selects the
# listed register.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# 0x00: BYPASS ("JTAG recommends this encoding"). Spike treats 0x00 as
# unsupported and keeps the old DR (spec value: captured 0, 1-bit delay).
dtm_ir 0x00
dtm_dr 16 0xa5c3
dtm_check 0xffff 0x4b86
# 0x01: IDCODE (Wally's preset; Spike's is 0xdeadbeef)
dtm_ir $IR_IDCODE
dtm_dr 32 0
dtm_check 0xffffffff $WALLY_IDCODE
# 0x10: dtmcs (version 1, abits 7)
dtm_ir $IR_DTMCS
dtm_dr 32 0
dtm_check 0x3ff
# 0x11: dmi (41 bits: write data0, read it back)
dtm_ir $IR_DMI
dmi_scan $DM_DATA0 0x1234abcd 2
dmi_scan $DM_DATA0 0 1
dmi_scan 0 0 0
dtm_check 0x1ffffffffff
# 0x12-0x17: reserved (BYPASS)
foreach ir {0x12 0x13 0x14 0x15 0x16 0x17} {
    dtm_ir $ir
    dtm_dr 16 0xa5c3
    dtm_check 0xffff 0x4b86
}
# 0x1f: BYPASS ("JTAG requires this encoding"). IEEE 1149.1: BYPASS
# captures 0 (Spike captures the last bit shifted in).
dtm_ir $IR_BYPASS
dtm_dr 16 0xa5c3
dtm_check 0xffff 0x4b86

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
