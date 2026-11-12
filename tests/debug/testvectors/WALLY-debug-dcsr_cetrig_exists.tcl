######################################################################
# WALLY-debug-dcsr_cetrig_exists
# Rule dcsr_cetrig_exists: "This bit is part of ((Smdbltrp)) and
# only exists when that extension is implemented."
#
# Wally does not implement Smdbltrp, so dcsr.cetrig (bit 19) does
# not exist and must read 0. Write dcsr with cetrig=1 (and prv=M,
# ebreakm=1) and read it back: bit 19 must be 0.
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
set_dcsr 3 ebreakm [expr {1 << 19}]
check_rd $CSR_DCSR [expr {1 << 19}]
sd_finish
