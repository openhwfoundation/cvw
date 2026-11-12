######################################################################
# WALLY-debug-dm_access_register_postexec_disabled
# Rule dm_access_register_postexec_disabled: "No effect. This variant
# must be supported, and is the only supported one if progbufsize is
# 0."
#
# postexec=0 must be supported (read of x26 works); with progbufsize=0
# (checked) it is the only supported value, so postexec=1 gives
# cmderr=2.
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
cmd_wait [access_reg_cmd [gpr 26] $XSZ 0]
check_cmderr
check_data $XSZ
tv_check $DM_ABSTRACTCS 0x1f000000
# data0 = 0 (an illegal instruction) so Spike's postexec stops at once.
set_arg0 3 0
cmd_wait [expr {1 << 18}]
# Spec: postexec=0 "is the only supported one if progbufsize is 0", and
# unsupported options give cmderr 2. (Spike runs its empty program
# buffer and reports 3.)
check_cmderr 2

clear_cmderr
finish_test $objdump_file $XSZ
