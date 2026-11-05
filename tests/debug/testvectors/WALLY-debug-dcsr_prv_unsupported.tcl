######################################################################
# WALLY-debug-dcsr_prv_unsupported
# Rule dcsr_prv_unsupported: "If the encoding written is not
# supported or the debugger is not allowed to change to it, the hart
# may change to any supported privilege mode."
#
# Write dcsr.prv=2, an encoding no hart without H supports, and
# resume at an ecall. The hart may run in any supported mode, so the
# ecall's mcause must be 8, 9 or 11 (U, S or M) and code after it
# must reach the ebreak: s2=1.
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
sd_run [lbl probe] 2 ebreakall
check_rd [gpr s2]
sd_finish
