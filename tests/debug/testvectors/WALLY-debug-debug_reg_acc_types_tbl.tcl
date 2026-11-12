######################################################################
# WALLY-debug-debug_reg_acc_types_tbl
# Rule debug_reg_acc_types_tbl:
#   "=== R|Read-only.¶R/W|Read/Write.¶R/W1C|Read/Write Ones to Clear.
#   Writing 0 to every bit has no effect. Writing 1 to every bit
#   clears the field. The result of other writes is
#   undefined.¶WARZ|Write any, read zero. A debugger may write any
#   value. When read this field returns 0.¶W1|Write-only. Only ..."
# Test: writes 1 to each WARZ/W1 field of dmcontrol (haltreq, resumereq,
# ackhavereset, ackunavail, setkeepalive, clrkeepalive,
# setresethaltreq, clrresethaltreq) and checks that it reads back 0.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
# No servers: concurrent generations would collide on their ports
gdb port disabled
telnet port disabled
tcl port disabled
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmrun.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# WARZ: "When read this field returns 0." W1: "When read the
# returned value should be 0." (Spike reads back haltreq and resumereq.)
dmc_wr $HALTREQ
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $HALTREQ 0
wait_halted
dmc_wr 0
dmc_wr $RESUMEREQ
dmi_rd $DM_DMCONTROL
tv_check $DM_DMCONTROL $RESUMEREQ 0
wait_running
foreach bit [list $ACKHAVERESET $ACKUNAVAIL $SETKEEPALIVE $CLRKEEPALIVE $SETRESETHALTREQ $CLRRESETHALTREQ] {
    dmc_wr $bit
    dmi_rd $DM_DMCONTROL
    tv_check $DM_DMCONTROL $bit 0
}

# Leave the test
halt_hart_twice
finish_test $objdump_file [xsize]
