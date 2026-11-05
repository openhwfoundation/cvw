######################################################################
# WALLY-debug-Sdext_debug_mode_m_priv
# Rule Sdext_debug_mode_m_priv: "All operations are executed with
# machine mode privilege, except that additional Debug Mode CSRs are
# accessible and mprv in mstatus may be ignored according to
# mprven."
#
# Halt the hart in U-mode (ebreak with ebreaku=1, mcounteren=0).
# Abstract commands then write and read M-mode CSRs (mscratch, mepc)
# and read mcycle; each must succeed (cmderr=0) and return the
# written value, because Debug Mode runs with M-mode privilege.
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
wr 0x306 0
sd_run [lbl probe] 0 ebreakall
wr $CSR_MSCRATCH 0x5a5a
check_cmderr
check_rd $CSR_MSCRATCH
wr $CSR_MEPC [lbl probe]
check_cmderr
check_rd $CSR_MEPC
rd $CSR_MCYCLE
check_cmderr
sd_finish
