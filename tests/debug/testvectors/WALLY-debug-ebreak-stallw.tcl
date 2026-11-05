######################################################################
# Receives the following arguments when called from debugtestgen.py
# ISA32      [32/64]
# BUILD_DIR  [build32/build]
# TEST_NAME  [WALLY-debug-******]
######################################################################

log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off

######################################################################
# Utility functions
######################################################################
proc get_address {filename label} {
    if {[catch {set fd [open $filename r]} err]} {
        error "Couldn't open $filename: $err"
    }
    set regex "^(\[0-9a-fA-f\]+)\\s+<${label}"
    while {[gets $fd line] != -1} {
        if {[regexp $regex $line match address]} {
            return "0x[string range $address 0 15]"
        }
    }
    error "Label not find in $filename: $label"
}

proc message {STR} {
    global TEST_NAME
    echo "$TEST_NAME: $STR"
}

proc clear_haltreq {} {
    riscv dmi_write 0x10 1
}

set AARSIZE [expr {3 - $ISA32}]

proc copy_csr_to_gpr {csr gpr} {
    global AARSIZE
    riscv dmi_write 0x17 [format 0x%08x [expr {($AARSIZE << 20) | (1 << 17) | $csr}]]
    echo "abstractcs = [riscv dmi_read 0x16]"
    riscv dmi_write 0x17 [format 0x%08x [expr {($AARSIZE << 20) | (1 << 17) | (1 << 16) | (0x1000 + $gpr)}]]
    echo "abstractcs = [riscv dmi_read 0x16]"
}

set DCSR 0x7b0
set A2 12

# --------------------------------------------------------------------
# Load labels from object dump
# --------------------------------------------------------------------

set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set cold         [get_address $objdump_file cold]
set after_ebreak [get_address $objdump_file after_ebreak]
set mark_cause   [get_address $objdump_file mark_cause]
set check_all    [get_address $objdump_file check_all]

# --------------------------------------------------------------------
# Begin test
# --------------------------------------------------------------------

reset halt
riscv.cpu configure -ebreak halt
clear_haltreq

resume
halt

set_reg [list dpc $cold]
resume
halt

set_reg [list dpc $after_ebreak]
resume
halt

copy_csr_to_gpr $DCSR $A2
set_reg [list dpc $mark_cause]
resume
halt

set_reg [list dpc $check_all]
resume
