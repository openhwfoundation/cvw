######################################################################
# WALLY-debug-Sdext_debug_mode_trap_no_csr_update
# Rule Sdext_debug_mode_trap_no_csr_update: "Because they do not
# trap to M-mode, they do not update registers such as mstatus,
# mepc, mcause, mtval, mtval2, and mtinst. The same is true for the
# equivalent privileged registers that are updated when trapping to
# other modes."
#
# Halt in M-mode and set mcause, mepc and mtval to known values. Run
# two abstract commands that raise an exception in Debug Mode (read
# of the nonexistent CSR 0x8ff, write of read-only mhartid). Check
# that mstatus, mepc, mcause and mtval are unchanged.
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
wr $CSR_MCAUSE 5
wr $CSR_MEPC [lbl probe]
wr $CSR_MTVAL 0x77
rd $CSR_MSTATUS
dmi_wr $DM_COMMAND [access_reg_cmd 0x8ff $SZ 0]
wait_abstract
clear_cmderr
abs_write 0xf14 $SZ 1
clear_cmderr
check_rd $CSR_MSTATUS
check_rd $CSR_MEPC
check_rd $CSR_MCAUSE
check_rd $CSR_MTVAL
sd_finish
