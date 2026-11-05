######################################################################
# WALLY-debug-dcsr_ebreakvs_rdonly0_no_H
# Rule dcsr_ebreakvs_rdonly0_no_H: "This bit is hardwired to 0 if
# the hart does not support virtualization mode."
#
# Wally does not implement the H extension, so dcsr.ebreakvs (bit
# 17) does not exist and must read 0. Write dcsr with ebreakvs=1
# (and prv=M, ebreakm=1) and read it back: bit 17 must be 0.
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
set_dcsr 3 ebreakm [expr {1 << 17}]
check_rd $CSR_DCSR [expr {1 << 17}]
sd_finish
