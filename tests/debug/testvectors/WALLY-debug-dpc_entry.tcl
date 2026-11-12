######################################################################
# WALLY-debug-dpc_entry
# Rule dpc_entry: "Upon entry to debug mode, dpc is updated with the
# virtual address of the next instruction to be executed."
#
# dpc must hold the virtual address. The program maps virtual
# 0x40000000 onto physical 0x80000000 (Sv39 gigapage on RV64, Sv32
# megapage on RV32) plus an identity mapping. M-mode setup code
# turns on translation and enters S-mode at the virtual alias of
# s_code with mret. The S-mode ebreak must halt with dpc = the
# ebreak's virtual address; then a step from the virtual address of
# s_code must give dpc = the next virtual address.
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
set_dcsr 3 ebreakall
sd_run [lbl vm_setup] 3 ebreakall
check_rd $CSR_DPC
set va [expr {[lbl s_code] - 0x40000000}]
sd_run $va 1 ebreakall step
check_rd $CSR_DPC
sd_finish
