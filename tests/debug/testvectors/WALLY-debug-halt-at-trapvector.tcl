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
    echo "$TEST_NAME: $STR"
    # echo $STR
}

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------

# Grab tests
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set trap_handler2 [get_address $objdump_file trap_handler2]
set trap_here [get_address $objdump_file trap_here]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------

# Halt if ebreak did not halt
reset halt

riscv.cpu configure -ebreak halt
message [read_reg dcsr]

# Need to set t3
# set_reg [list t3 1]
#message "PC: [read_reg pc]"

# Reset. Should already be halted once ebreak is hit.
resume

# NOTE: With polling off, running an extra halt command, even though
# we expect to halt on an ebreak, is necessary to force OpenOCD to
# update it's internal tracking state.
halt
set_reg [list mtvec $trap_handler2]

set_reg [list dpc $trap_here]
message "PC: [read_reg pc]"
step
message "PC: [read_reg pc]"
step
message "Should be trap vector $trap_handler2: [read_reg pc]"

# At this point we should be able to step through and take the trap
# vector
#set_reg [list dpc $write_val]

# Test should finish here
resume
