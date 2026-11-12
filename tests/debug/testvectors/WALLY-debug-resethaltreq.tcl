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

# Utility function for scraping object dump files and grabbing label
# addresses.
proc get_address {filename label} {
    if {[catch {set fd [open $filename r]} err]} {
        error "Couldn't open $filename: $err"
    } else {
        puts "Successfully opened the file $filename"
    }

    # Iterate over every line and find the match. There should be only
    # one match.
    #set regex "^(\[0-9a-fA-f\]{16})\\s+<${label}"
    set regex "^(\[0-9a-fA-f\]+)\\s+<${label}"
    while {[gets $fd line] != -1} {
        if {[regexp $regex $line match address]} {
            # Convert address to OpenOCD format (e.g., 0x80000010)
            return "0x[string range $address 0 15]"
        }
    }

    error "Label not find in $filename: $label"
}

# Reads a register and converts it's hexadecimal value into an
# integer value.
proc read_reg {register} {
    set regval [lindex [reg $register] 2]
    return [expr {$regval}]
}

proc message {STR} {
    global TEST_NAME
    echo $TEST_NAME:
    echo $STR
}

#
proc set_rhq {} {
    set dmcontrol [riscv dmi_read 0x10]
    set setresethaltreq 3
    set dmcontrol [expr {$dmcontrol | (1 << $setresethaltreq)}]
    riscv dmi_write 0x10 $dmcontrol
}

proc clear_rhq {} {
    set setresethaltreq 3
    set clrresethaltreq 2
    set dmcontrol [riscv dmi_read 0x10]
    set dmcontrol [expr {$dmcontrol & ~(1 << $setresethaltreq) | (1 << $clrresethaltreq)}]
    riscv dmi_write 0x10 $dmcontrol
}

proc resethaltreq {} {
    set_rhq
    reset
    clear_rhq
}

proc reset_no_ebreak {} {
    reset halt
    core.tap configure -ebreak exception
    resume
}

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------

# Grab tests
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set halt1 [get_address $objdump_file halt1]
set test_end [get_address $objdump_file test_end]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------

# Halt if ebreak did not halt
#halt
reset halt
resume
halt
set_reg [list t0 0x00fa11ed]

set_rhq
reset
clear_rhq
# halt if not already halted
halt
resume
halt
set_reg [list dpc $test_end]
resume
