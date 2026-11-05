######################################################################
# WALLY-debug-dm_auth_authdata_omit
# Rule dm_auth_authdata_omit: "Implementations where it’s not possible
# to unlock the DM by using authdata should not implement that
# register."
#
# (Recommendation) Wally needs no authentication
# (dmstatus.authenticated=1), so authdata is not implemented: it reads
# 0 after a write.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off
source testvectors/lib/rules.tcl
source testvectors/lib/dmabs.tcl
tv_rule
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

dmi_rd $DM_DMSTATUS
tv_check $DM_DMSTATUS 0xc0
dmi_wr $DM_AUTHDATA 0x12345678
dmi_rd $DM_AUTHDATA
# Spec: implementations that can't be unlocked through authdata "should
# not implement that register"; unimplemented registers read 0. (Spike
# returns its authentication challenge.)
tv_check $DM_AUTHDATA 0xffffffff 0
halt_hart

clear_cmderr
finish_test $objdump_file $XSZ
