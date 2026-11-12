######################################################################
# WALLY-debug-resume-mprv
# Receives from debugtestgen.py: ISA32 [0/1], BUILD_DIR, TEST_NAME
#
# Linear (no result-dependent branches). Both halts are ebreak halts,
# so the "resume; halt" pairs are deterministic.
######################################################################

log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off

proc get_address {filename label} {
    if {[catch {set fd [open $filename r]} err]} {
        error "Couldn't open $filename: $err"
    }
    set regex "^(\[0-9a-fA-f\]+)\\s+<${label}>"
    while {[gets $fd line] != -1} {
        if {[regexp $regex $line match address]} {
            return "0x[string range $address 0 15]"
        }
    }
    error "Label not find in $filename: $label"
}

set AARSIZE [expr {3 - $ISA32}]

# Abstract command: CSR -> data0, then data0 -> GPR (no DMI read of
# data0, so the value only reaches the signature through the program).
proc copy_csr_to_gpr {csr gpr} {
    global AARSIZE
    riscv dmi_write 0x17 [format 0x%08x [expr {($AARSIZE << 20) | (1 << 17) | $csr}]]
    echo "abstractcs = [riscv dmi_read 0x16]"
    riscv dmi_write 0x17 [format 0x%08x [expr {($AARSIZE << 20) | (1 << 17) | (1 << 16) | (0x1000 + $gpr)}]]
    echo "abstractcs = [riscv dmi_read 0x16]"
}

set MSTATUS 0x300
set A2 12

set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set u_code [get_address $objdump_file u_code]
set check  [get_address $objdump_file check]

# --------------------------------------------------------------------
# Halt #1: ebreak at end of M-mode setup (MPRV=1, MPP=M, PMP X-only)
# --------------------------------------------------------------------
reset halt
riscv.cpu configure -ebreak halt
resume
halt

# Leave Debug Mode into U-mode at u_code. MPRV is still 1 here; the
# hart must clear it on resume because prv(U) < M.
reg priv 0
set_reg [list dpc $u_code]
resume

# --------------------------------------------------------------------
# Halt #2: ebreak in trap_handler (correct) or in u_code (MPRV leaked)
# --------------------------------------------------------------------
halt
copy_csr_to_gpr $MSTATUS $A2
reg priv 3
set_reg [list dpc $check]
resume
