######################################################################
# WALLY-debug-dcsr_acc
# Rule dcsr_acc: "This CSR is read/write."
#
# Write dcsr with different values of the writable fields
# (ebreakm/s/u, step, prv) and read each back.
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

set mask [expr {$DCSR_EBREAKALL | $DCSR_STEP | $DCSR_PRV}]
sd_begin
set_dcsr 0 ebreakm ebreaku step
check_rd $CSR_DCSR $mask
set_dcsr 1 ebreaks
check_rd $CSR_DCSR $mask
set_dcsr 3 ebreakall
check_rd $CSR_DCSR $mask
sd_finish
