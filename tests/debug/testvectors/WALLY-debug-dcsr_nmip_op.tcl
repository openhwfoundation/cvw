######################################################################
# WALLY-debug-dcsr_nmip_op
# Rule dcsr_nmip_op: "When set, there is a Non-Maskable-Interrupt
# (NMI) pending for the hart."
#
# Wally has no NMI, so no NMI is ever pending and dcsr.nmip must
# read 0. Read dcsr after a halt, then write nmip=1 (a read-only
# field) and read it again.
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
check_rd $CSR_DCSR $DCSR_NMIP
set_dcsr 3 ebreakm $DCSR_NMIP
check_rd $CSR_DCSR $DCSR_NMIP
sd_finish
