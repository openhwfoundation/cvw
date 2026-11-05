######################################################################
# WALLY-debug-dcsr_prv_v_enc
# Rule dcsr_prv_v_enc: "H extension
# supported|v|prv|Abbreviation|Name === No|0|0|U-mode|User
# mode¶No|0|1|S-mode|Supervisor mode¶No|0|3|M-mode|Machine
# mode¶Yes|0|0|U-mode|User mode¶Yes|0|1|HS-mode|Hypervisor-enabled
# supervisor mode¶Yes|0|3|M-mode|Machine mode¶Yes|1|0|VU-
# mode|Virtual user mode¶Yes|1|1|VS-mode|Virtual supervisor mode
# ==="
#
# Halt with haltreq while the hart spins in U-mode, S-mode and
# M-mode. dcsr.v must be 0 and dcsr.prv must be 0, 1 and 3 (the
# encodings for a hart without H).
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
foreach prv {0 1 3} {
    sd_go [lbl spin] $prv ebreakall
    sleep 100
    halt_hart
    check_rd $CSR_DCSR [expr {$DCSR_V | $DCSR_PRV}]
}
sd_finish
