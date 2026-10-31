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
set doloop [get_address $objdump_file doloop]
set setup_test [get_address $objdump_file setup_test]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------

# Trap vector should have been hit. We need to restart the test so
# that we can configure ebreak.
reset halt

# This test assumes ebreak works. If ebreak does not work, refer to
# the ebreak test. The following command configures ebreak in M-mode,
# S-mode, and U-mode
riscv.cpu configure -ebreak halt

# Reset. Should already be halted once ebreak is hit.
resume

# NOTE: With polling off, running an extra halt command, even though
# we expect to halt on an ebreak, is necessary to force OpenOCD to
# update it's internal tracking state. Otherwise, OpenOCD would have
# polled DCSR an detected the state change itself.
halt
message [read_reg pc]

# Run the loop. Hopefully the next halt occurs during the middle of
# the loop and not on the jump or store instruction. The goal is to
# run an instruction a second time that will change the memory
# signature.
set_reg [list dpc $setup_test]
resume

# this should halt at a random location
halt

# Now we'll resume and let the program continue. If halting caused an
# instruction to run again, the signature will change.

# Test should finish after this.
resume
