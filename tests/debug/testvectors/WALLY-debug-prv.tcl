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

proc reset_no_ebreak {} {
    reset halt
    core.tap configure -ebreak exception
    resume
}

proc goto {address} {
    set_reg [list dpc $address]
}

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------

# Grab labels
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set prvtest [get_address $objdump_file prvtest]
set test_end [get_address $objdump_file test_end]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------

# Halt if ebreak did not halt
# halt
reset halt
riscv.cpu configure -ebreak halt
resume
halt
goto $prvtest
step

# Chang to M-Mode
reg priv 3
puts [reg priv]
resume
