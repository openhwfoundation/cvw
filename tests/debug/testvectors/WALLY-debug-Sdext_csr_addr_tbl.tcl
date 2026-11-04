######################################################################
# WALLY-debug-Sdext_csr_addr_tbl
# Rule Sdext_csr_addr_tbl: "Address|Name|Section === 0x7b0|Debug
# Control and Status (dcsr)|¶0x7b1|Debug PC (dpc)|¶0x7b2|Debug
# Scratch Register 0 (dscratch0)|¶0x7b3|Debug Scratch Register 1
# (dscratch1)| ==="
#
# Halt on an ebreak, then read CSR 0x7b0 (dcsr: debugver, cause=1,
# prv=3) and 0x7b1 (dpc = address of the ebreak) with abstract
# commands.
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
sd_run [lbl probe] 3 ebreakm
check_rd 0x7b0 [expr {0xf0000000 | $DCSR_CAUSE | $DCSR_PRV}]
check_rd 0x7b1
sd_finish
