######################################################################
# WALLY-debug-dcsr_cause_priority_tbl
# Rule dcsr_cause_priority_tbl: "cause encoding|Cause ===
# 5|resethaltreq¶6|halt group¶3|haltreq¶2|trigger (See for detailed
# priority)¶1|ebreak¶4|step ==="
#
# Step (dcsr.step=1) over an ebreak with ebreakm=1. Both step and
# ebreak cause Debug Mode entry; ebreak has higher priority, so
# dcsr.cause = 1 and dpc = the ebreak.
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
sd_run [lbl probe_ebreak] 3 ebreakm step
check_rd $CSR_DCSR $DCSR_CAUSE
check_rd $CSR_DPC
sd_finish
