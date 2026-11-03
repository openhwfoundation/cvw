######################################################################
# WALLY-debug-dcsr_stopcount_freeze
# Rule dcsr_stopcount_freeze: "Don't increment any hart-local
# counters while in Debug Mode or on ebreak instructions that cause
# entry into Debug Mode. These counters include the instret CSR."
#
# With dcsr.stopcount=1 (Wally implements it), read minstret, halt
# on an ebreak, wait in Debug Mode, resume after the ebreak, and
# read minstret again. Only the first csrr may be counted: the
# halting ebreak and Debug Mode add nothing, so the difference is 1.
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
# Spec: stopcount=1 "Don't increment any hart-local counters while in
# Debug Mode or on ebreak instructions that cause entry into Debug
# Mode. These counters include the instret CSR." Only the first csrr
# retires between the two reads: difference 1. Spike hardwires
# stopcount to 0 and keeps counting.
check_rd [gpr a0] -1 1
sd_finish
