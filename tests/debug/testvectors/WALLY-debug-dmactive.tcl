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

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------
# Base name for test
puts [pwd]

# Grab tests
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set test2_addr [get_address $objdump_file test2]
set test3_addr [get_address $objdump_file test3]
set test4_addr [get_address $objdump_file test4]
set test_end_addr [get_address $objdump_file test_end]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------
halt

# display current PC for debug purposes. This introduces DMI comands
# for grabbing the PC value.
puts [reg pc]

# Begin halt/resume cycle to progress test
set_reg [list dpc $test2_addr]

resume
halt

set_reg [list dpc $test3_addr]

resume
halt

set_reg [list dpc $test4_addr]

resume
halt

set_reg [list dpc $test_end_addr]

resume; # Final resume
