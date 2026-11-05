######################################################################
# WALLY-debug-Sdext_csr_unimp
# Rule Sdext_csr_unimp: "Attempts to access an unimplemented Core
# Debug Register raise an illegal instruction exception."
#
# Wally does not implement dscratch0/dscratch1. An abstract read of
# either must fail with an exception (cmderr=3). From M-mode outside
# Debug Mode, csrr of either must raise an illegal instruction
# exception (2 traps).
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
check_rd [gpr s2]
check_rd [gpr s3]
# Spec: "Attempts to access an unimplemented Core Debug Register raise
# an illegal instruction exception"; for an abstract command that is
# cmderr=3 (exception). Wally has no dscratch0/1; Spike implements them
# (they are optional) and returns cmderr=0.
rd $CSR_DSCRATCH0
check_cmderr 0x300
clear_cmderr
rd $CSR_DSCRATCH1
check_cmderr 0x300
clear_cmderr
sd_finish
