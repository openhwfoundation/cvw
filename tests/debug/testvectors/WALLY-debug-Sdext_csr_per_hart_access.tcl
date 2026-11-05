######################################################################
# WALLY-debug-Sdext_csr_per_hart_access
# Rule Sdext_csr_per_hart_access: "The supported Core Debug
# Registers must be implemented for each hart that can be debugged.
# They are CSRs, accessible using the RISC-V csr opcodes and
# optionally also using abstract debug commands."
#
# Halt the (only) hart and read dcsr and dpc with abstract commands.
# Both reads must succeed (cmderr=0); dcsr.debugver must be nonzero
# and dpc must hold the halt address.
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
check_rd $CSR_DCSR 0xf0000000
check_cmderr
check_rd $CSR_DPC
check_cmderr
sd_finish
