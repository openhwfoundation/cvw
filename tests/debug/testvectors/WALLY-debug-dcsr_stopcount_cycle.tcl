######################################################################
# WALLY-debug-dcsr_stopcount_cycle
# Rule dcsr_stopcount_cycle: "On single-hart cores cycle should be
# stopped, but on multi-hart cores it must keep incrementing."
#
# Wally is a single-hart core. With dcsr.stopcount=1, read mcycle,
# halt on an ebreak, wait in Debug Mode, resume, and read mcycle
# again. cycle should be stopped while halted: the difference is
# below 1000 (a1=1) although the halt lasts many thousands of
# cycles.
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
sd_run [lbl probe] 3 ebreakm stopcount

rd [gpr s6]
rd [gpr s6]
rd [gpr s6]
rd [gpr s6]

sd_run [lbl after] 3 ebreakm stopcount
# Spec: "On single-hart cores cycle should be stopped". Spike hardwires
# stopcount to 0, so its mcycle keeps counting while halted.
check_rd [gpr a1] -1 1
sd_finish
