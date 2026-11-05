######################################################################
# WALLY-debug-dm_access_register_op
# Rule dm_access_register_op: "If write is clear and transfer is set,
# then copy data from the register specified by regno into the arg0
# region of data, and perform any side effects that occur when this
# register is read from M-mode. If write is set and transfer is set,
# then copy data from the arg0 region of data into the regist..."
#
# Access Register read of x11 copies it to arg0; write copies arg0 to
# x12 (checked in the signature); writing fcsr from the DM has the
# M-mode side effect of updating frm and fflags, read back through
# their own CSRs.
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
cmd_wait [access_reg_cmd [gpr 11] $XSZ 0]
check_cmderr
check_data $XSZ
set_arg0 $XSZ 0x0c0ffee00c0ffee0
cmd_wait [access_reg_cmd [gpr 12] $XSZ 1]
check_cmderr
# fcsr = frm 5, fflags 0x13
set_arg0 $XSZ 0xb3
cmd_wait [access_reg_cmd 0x003 $XSZ 1]
check_cmderr
cmd_wait [access_reg_cmd 0x002 $XSZ 0]
check_cmderr
check_data $XSZ
cmd_wait [access_reg_cmd 0x001 $XSZ 0]
check_cmderr
check_data $XSZ

clear_cmderr
finish_test $objdump_file $XSZ
