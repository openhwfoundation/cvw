######################################################################
# WALLY-debug-Sdext_debug_mode_abstract_cmd
# Rule Sdext_debug_mode_abstract_cmd: "When executing code due to an
# abstract command, the hart stays in Debug Mode"
#
# Halt on an ebreak, then run abstract commands (CSR write and read,
# GPR read). Check that dmstatus still reports the hart halted
# (allhalted=1, allrunning=0) after them.
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
wr $CSR_MSCRATCH 0x1234
rd $CSR_MSCRATCH
rd [gpr s2]
check_halted
sd_finish
