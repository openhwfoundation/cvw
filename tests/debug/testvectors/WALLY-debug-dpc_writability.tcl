######################################################################
# WALLY-debug-dpc_writability
# Rule dpc_writability: "The writability of dpc follows the same
# rules as mepc as defined in the Privileged Spec. In particular,
# dpc must be able to hold all valid virtual addresses and the
# writability of the low bits depends on IALIGN."
#
# dpc follows mepc's writability: it holds every XLEN-bit value
# except bit 0, which is 0 because IALIGN=16 (C is implemented).
# Write all ones, then a value with bits 1 and 0 set, and read each
# back.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
# No gdb/telnet/tcl servers: parallel vector generation would collide on their ports
gdb port disabled
telnet port disabled
tcl port disabled
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/sdext.tcl
tv_rule

sd_begin
wr $CSR_DPC -1
check_rd $CSR_DPC
wr $CSR_DPC 0x80000123
check_rd $CSR_DPC
sd_finish
