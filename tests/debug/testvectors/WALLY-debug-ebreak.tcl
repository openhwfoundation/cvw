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

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------

# Grab tests
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set do_ebreak [get_address $objdump_file do_ebreak]
set resume_addr [get_address $objdump_file resume_addr]
set write_val [get_address $objdump_file write_val]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------

# Halt if ebreak did not halt
reset halt
#message [read_reg pc]
message [read_reg dcsr]

#set DCSR [read_reg dcsr]
#set DCSRNEW [expr {$DCSR | 2 ** 15}]
#set_reg [list dcsr $DCSRNEW]
riscv.cpu configure -ebreak halt
message [read_reg dcsr]

# Reset. Should already be halted once ebreak is hit.
resume

# NOTE: With polling off, running an extra halt command, even though
# we expect to halt on an ebreak, is necessary to force OpenOCD to
# update it's internal tracking state.
halt
message [read_reg pc]
#echo "Printing PC value"
#echo [reg pc]
set_reg [list dpc $write_val]

# Test should finish here
resume
