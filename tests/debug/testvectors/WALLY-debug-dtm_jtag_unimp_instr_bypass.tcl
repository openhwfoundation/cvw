######################################################################
# WALLY-debug-dtm_jtag_unimp_instr_bypass
# Rule dtm_jtag_unimp_instr_bypass: "Unimplemented instructions
#   must select the BYPASS register."
# For every unimplemented IR value (0x02-0x0f, 0x12-0x1e), a
# 16-bit DR scan must see the 1-bit BYPASS register: a captured 0,
# then TDI delayed by one bit.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dtm.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# Spike keeps the previous DR for unsupported IR values (spec values).
foreach ir {0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f
            0x12 0x13 0x14 0x15 0x16 0x17 0x18 0x19 0x1a 0x1b 0x1c 0x1d 0x1e} {
    dtm_ir $ir
    dtm_dr 16 0xa5c3
    dtm_check 0xffff 0x4b86
}

dtm_restore_dmi
halt_hart
finish_test $objdump_file [expr {3 - $ISA32}]
