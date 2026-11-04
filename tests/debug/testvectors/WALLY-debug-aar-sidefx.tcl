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

proc get_address {filename label} {
    if {[catch {set fd [open $filename r]} err]} {
        error "Couldn't open $filename: $err"
    } else {
        puts "Successfully opened the file $filename"
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

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------

set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set test_end [get_address $objdump_file test_end]

# [22:20] aarsize, [17] transfer, [16] write, [15:0] regno
# XLEN-sized GPR/CSR; FLEN==XLEN on Wally debug32/64 so same SZ for FPRs.
set SZ [expr {$ISA32 ? 2 : 3}]
proc aar {size transfer write regno} {
    return [format 0x%08x [expr {($size << 20) | ($transfer << 17) | ($write << 16) | $regno}]]
}

# CSR / FPR abstract regnos
set MSTATUS   0x0300
set MSCRATCH  0x0340
set MVENDORID 0x0f11
set FT0       0x1020

# --------------------------------------------------------------------
# Begin test
# --------------------------------------------------------------------

halt

# 1) Baseline: read mstatus; FS must still be Initial (01), not Dirty.
#    FS lives in [14:13]; only data0 is needed even on RV64.
riscv dmi_write 0x17 [aar $SZ 1 0 $MSTATUS]
message "1 read mstatus: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "1 mstatus data0=[riscv dmi_read 0x04] (expect FS=Initial, bits\[14:13\]=01)"
if {!$ISA32} {
    message "1 mstatus data1=[riscv dmi_read 0x05]"
}

# 2) Abstract write ft0 (f0). Must succeed. Wally sets mstatus.FS=Dirty;
#    Spike leaves FS=Initial — forgive FS bits in knownExceptions (see below).
#    Poison data first so a failed transfer is obvious on the readback.
riscv dmi_write 0x04 0x3f800000
riscv dmi_write 0x05 0x00000000
riscv dmi_write 0x17 [aar $SZ 1 1 $FT0]
message "2 write ft0: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"

riscv dmi_write 0x17 [aar $SZ 1 0 $MSTATUS]
message "2 mstatus after FPR write: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "2 mstatus data0=[riscv dmi_read 0x04] (Wally FS=Dirty 11; Spike often still Initial)"

riscv dmi_write 0x04 0x00000000
riscv dmi_write 0x05 0x00000000
riscv dmi_write 0x17 [aar $SZ 1 0 $FT0]
message "2 read ft0: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "2 ft0 data0=[riscv dmi_read 0x04] (expect 0x3f800000)"
if {!$ISA32} {
    message "2 ft0 data1=[riscv dmi_read 0x05] (expect 0)"
}

# 3) Write a read-only CSR (mvendorid). Must complete with cmderr=3.
#    Do not read back mvendorid data0 — Spike returns 0, Wally 0x602.
riscv dmi_write 0x04 0xffffffff
riscv dmi_write 0x05 0xffffffff
riscv dmi_write 0x17 [aar $SZ 1 1 $MVENDORID]
message "3 write mvendorid: abstractcs=[riscv dmi_read 0x16] (expect cmderr 3)"
riscv dmi_write 0x16 0x700

# 4) Happy-path CSR: write then read mscratch via AAR.
riscv dmi_write 0x04 0x600d5c6a
riscv dmi_write 0x05 0x00000000
riscv dmi_write 0x17 [aar $SZ 1 1 $MSCRATCH]
message "4 write mscratch: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"

riscv dmi_write 0x04 0x00000000
riscv dmi_write 0x17 [aar $SZ 1 0 $MSCRATCH]
message "4 read mscratch: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "4 mscratch data0=[riscv dmi_read 0x04] (expect 0x600d5c6a)"

halt
set_reg [list dpc $test_end]
resume
