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
}

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------

# Grab tests
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set m_setup   [get_address $objdump_file m_setup]
set s_setup   [get_address $objdump_file s_setup]

set m_target   [get_address $objdump_file m_target]
set s_target   [get_address $objdump_file s_target]

set post_ebreak_config [get_address $objdump_file post_ebreak_config]
set trap_handler [get_address $objdump_file trap_handler]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------

# Configure ebreak
reset halt
riscv.cpu configure -ebreak halt
message [read_reg dcsr]

# M-mode section
resume; halt
set_reg [list dpc $post_ebreak_config]
resume; halt
set_reg [list mtvec $trap_handler]
set_reg [list dpc $m_setup]
step
step
step
message "Expected PC: $m_target | Actual PC: [read_reg pc]"

# S-mode section
resume; halt
set_reg [list dpc $s_setup]
step
step
step
message "Expected PC: $s_target | Actual PC: [read_reg pc]"

resume
