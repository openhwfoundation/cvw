######################################################################
# WALLY-debug-dpc_acc
# Rule dpc_acc: "This CSR is read/write."
#
# Write dpc with two different values and read each back.
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
wr $CSR_DPC [expr {[lbl probe] + 0x100}]
check_rd $CSR_DPC
wr $CSR_DPC 0x12345678
check_rd $CSR_DPC
sd_finish
