######################################################################
# WALLY-debug-dm_abstractauto_optional
# Rule dm_abstractauto_optional: "This register is optional."
#
# Wally does not implement abstractauto: it reads 0 after writing all
# ones, and a data0 write after a read command does not re-execute the
# command.
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
dmi_wr $DM_ABSTRACTAUTO 0xffffffff
dmi_rd $DM_ABSTRACTAUTO
# Spec: abstractauto "is optional"; unimplemented DM registers "return 0
# when read. Writing them has no effect." (Spike implements it.)
tv_check $DM_ABSTRACTAUTO 0xffffffff 0
cmd_wait [access_reg_cmd [gpr 11] $XSZ 0]
dmi_wr $DM_DATA0 0x5a5a5a5a
dmi_rd $DM_DATA0
# With no autoexecdata, data0 keeps the written value. (Spike re-runs the
# read of x11.)
tv_check $DM_DATA0 0xffffffff 0x5a5a5a5a
dmi_wr $DM_ABSTRACTAUTO 0

clear_cmderr
finish_test $objdump_file $XSZ
