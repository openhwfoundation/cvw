######################################################################
# WALLY-debug-dm_access_register_regno_enc
# Rule dm_access_register_regno_enc: "Numbers|Group Description ===
# 0x0000 — 0x0fff|CSRs. The ``PC'' can be accessed here through
# dpc.¶0x1000 — 0x101f|GPRs¶0x1020 — 0x103f|Floating point
# registers¶0xc000 — 0xffff|Reserved for non-standard extensions and
# internal use. ==="
#
# regno 0x1000+n is GPR n (x13, x31), 0x1020+n is FPR n (f5, f31),
# 0x0000-0x0fff are CSRs (mscratch 0x340), and the PC is read through
# dpc (0x7b1).
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

halt_hart
foreach {r sz} [list 0x100d $XSZ 0x101f $XSZ 0x1025 3 0x103f 3 0x340 $XSZ 0x7b1 $XSZ] {
    cmd_wait [access_reg_cmd $r $sz 0]
    check_cmderr
    check_data $sz
}

clear_cmderr
finish_test $objdump_file $XSZ
