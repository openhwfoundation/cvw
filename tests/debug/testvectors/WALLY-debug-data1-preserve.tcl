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
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set test1_addr [get_address $objdump_file test1]
set test_end [get_address $objdump_file test_end]

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------
# Program has stored t0/t1 once and spins after test1.
# t0 = 0x1122334455667788, t1 = 0x0bad0bad0bad0bad
halt

# Known patterns in data0/data1
riscv dmi_write 0x04 0x00000000
riscv dmi_write 0x05 0xcafef00d

# aarsize=2 (32-bit), transfer, read x5 (t0)
riscv dmi_write 0x17 0x00221005
echo "abstractcs = [riscv dmi_read 0x16]"
echo "data0 = [riscv dmi_read 0x04] (expect 0x55667788)"
echo "data1 = [riscv dmi_read 0x05] (expect 0xcafef00d, unchanged)"

# aarsize=3 (64-bit), transfer, write x6 (t1) <- {data1, data0}
# Correct: t1 = 0xcafef00d55667788. If the 32-bit read clobbered
# data1, t1 = 0x1122334455667788. Stored to the signature below.
riscv dmi_write 0x17 0x00331006
echo "abstractcs = [riscv dmi_read 0x16]"

# aarsize=3 (64-bit), transfer, read x5 (t0)
riscv dmi_write 0x17 0x00321005
echo "abstractcs = [riscv dmi_read 0x16]"
echo "data0 = [riscv dmi_read 0x04] (expect 0x55667788)"
echo "data1 = [riscv dmi_read 0x05] (expect 0x11223344)"

# Store t0/t1 to the signature again
set_reg [list dpc $test1_addr]
resume

halt
set_reg [list dpc $test_end]
resume
