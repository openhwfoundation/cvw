######################################################################
# WALLY-debug-dpc_resume
# Rule dpc_resume: "When resuming, the hart's PC is updated to the
# virtual address stored in dpc."
#
# Write dpc with an address other than the halt address and resume;
# the hart must continue there. (1) M-mode, dpc = a 2-byte-aligned
# c.li: s2=6 at the next ebreak, and dpc = that ebreak. (2) With
# Sv39/Sv32 translation on (virtual 0x40000000 maps to physical
# 0x80000000), resume in S-mode with dpc = the virtual alias of
# s_target: s3=1 at the next ebreak, and dpc = that ebreak's virtual
# address.
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
sd_run [lbl target] 3 ebreakm
check_rd [gpr s2]
check_rd $CSR_DPC
sd_run [lbl vm_setup] 3 ebreakall
sd_run [expr {[lbl s_target] - 0x40000000}] 1 ebreakall
check_rd [gpr s3]
check_rd $CSR_DPC
sd_finish
