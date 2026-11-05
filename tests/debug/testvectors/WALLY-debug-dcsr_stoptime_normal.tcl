######################################################################
# WALLY-debug-dcsr_stoptime_normal
# Rule dcsr_stoptime_normal: "time continues to reflect mtime."
#
# Wally hardwires dcsr.stoptime to 0. Read time, halt on an ebreak,
# wait in Debug Mode, resume, and read time again. time must have
# kept following mtime: the difference exceeds 1000 (s2=1); Wally's
# mtime counts clock cycles and the halt lasts many thousands of
# them.
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
check_rd $CSR_DCSR $DCSR_STOPTIME

rd [gpr s6]
rd [gpr s6]
rd [gpr s6]
rd [gpr s6]

sd_run [lbl after] 3 ebreakm
check_rd [gpr s2]
sd_finish
