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
# Program has stored its registers once and spins after test1.
# t0 = 0x55667788, t1 = 0x0bad0bad, t2 = 0x0badf00d,
# f1 = 0x0123456789abcdef, f2 = 0x0bad0bad0bad0bad
halt

# Known patterns in data0/data1
riscv dmi_write 0x04 0xa5a5a5a5
riscv dmi_write 0x05 0xcafef00d

# aarsize=3 (64-bit), transfer, read x5 (t0). Not supported on RV32:
# cmderr must be nonzero and data0/data1 must be unchanged.
# (The spec says cmderr 2; Spike reports 3, see debugger.sv knownExceptions.)
riscv dmi_write 0x17 0x00321005
echo "abstractcs = [riscv dmi_read 0x16] (expect cmderr != 0)"
echo "data0 = [riscv dmi_read 0x04] (expect 0xa5a5a5a5, unchanged)"
echo "data1 = [riscv dmi_read 0x05] (expect 0xcafef00d, unchanged)"

# cmderr is still set: this aarsize=2 write of x6 (t1) <- data0 must
# be ignored, so t1 keeps its sentinel 0x0bad0bad. abstractcs is not
# read here because Spike and Wally report different nonzero cmderr.
riscv dmi_write 0x17 0x00231006

# Clear cmderr (W1C)
riscv dmi_write 0x16 0x700
echo "abstractcs = [riscv dmi_read 0x16] (expect cmderr 0)"

# aarsize=2 (32-bit), transfer, write x7 (t2) <- data0.
# t2 = 0xa5a5a5a5 proves data0 was not touched by the failed command.
riscv dmi_write 0x17 0x00231007
echo "abstractcs = [riscv dmi_read 0x16] (expect cmderr 0)"

# aarsize=3 (64-bit), transfer, write f2 <- {data1, data0}.
# f2 = 0xcafef00da5a5a5a5 proves data1 was not touched either.
riscv dmi_write 0x17 0x00331022
echo "abstractcs = [riscv dmi_read 0x16] (expect cmderr 0)"

# aarsize=2 (32-bit), transfer, read x5 (t0)
riscv dmi_write 0x17 0x00221005
echo "abstractcs = [riscv dmi_read 0x16] (expect cmderr 0)"
echo "data0 = [riscv dmi_read 0x04] (expect 0x55667788)"

# aarsize=3 (64-bit), transfer, read f1. D is supported, so accepted.
riscv dmi_write 0x17 0x00321021
echo "abstractcs = [riscv dmi_read 0x16] (expect cmderr 0)"
echo "data0 = [riscv dmi_read 0x04] (expect 0x89abcdef)"
echo "data1 = [riscv dmi_read 0x05] (expect 0x01234567)"

# Store t0, t1, t2, f2 to the signature again
set_reg [list dpc $test1_addr]
resume

halt
set_reg [list dpc $test_end]
resume
