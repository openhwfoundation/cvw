######################################################################
# WALLY-debug-dcsr_stopcount_normal
# Rule dcsr_stopcount_normal: "Increment counters as usual."
#
# With dcsr.stopcount=0, read mcycle, halt on an ebreak, wait in
# Debug Mode, resume, and read mcycle again. The counter must have
# kept counting while halted: the difference exceeds 1000 (s2=1).
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

rd [gpr s6]
rd [gpr s6]
rd [gpr s6]
rd [gpr s6]

sd_run [lbl after] 3 ebreakm
check_rd [gpr s2]
sd_finish
