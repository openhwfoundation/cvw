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
# XLEN-sized accesses (aarsize=2 write sign-extends in Spike, zero-extends in Wally on RV64)
set SZ [expr {$ISA32 ? 2 : 3}]
proc aar {size transfer write regno} {
    return [format 0x%08x [expr {($size << 20) | ($transfer << 17) | ($write << 16) | $regno}]]
}

# --------------------------------------------------------------------
# Begin test
# --------------------------------------------------------------------

halt
riscv dmi_write 0x04 0xa5a5a5a5
riscv dmi_write 0x05 0xcafef00d

# 1) transfer=0 with write=1 targeting x6.
#    Spec: transfer=0 means no register access; aarsize/write/regno are ignored.
#    Expect abstractcs.cmderr=0 and x6 left at its .S sentinel (checked in step 6).
riscv dmi_write 0x17 [aar $SZ 0 1 0x1006]
message "1 transfer=0 write x6: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"

# 2) transfer=0 again, but with illegal aarsize=0 on a read of x5.
#    Size must not matter when transfer=0 — still a successful no-op.
#    data0 must stay at the poison written above (no accidental transfer).
riscv dmi_write 0x17 [aar 0 0 0 0x1005]
message "2 transfer=0 aarsize=0: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "2 data0=[riscv dmi_read 0x04] (expect 0xa5a5a5a5)"

# 3) aarsize=0 with transfer=1 read of x5 --> unsupported size --> cmderr=2.
#    data0 must remain poison (failed command must not transfer).
#    Then try a legal write of x7 while cmderr is still sticky — must stay cmderr=2
#    and leave x7 untouched (checked in step 6). Clear cmderr with W1C before leaving.
riscv dmi_write 0x17 [aar 0 1 0 0x1005]
message "3 aarsize=0 read x5: abstractcs=[riscv dmi_read 0x16] (expect cmderr 2)"
message "3 data0=[riscv dmi_read 0x04] (expect 0xa5a5a5a5, unchanged)"
riscv dmi_write 0x17 [aar $SZ 1 1 0x1007]
message "3 sticky blocks write x7: abstractcs=[riscv dmi_read 0x16] (expect cmderr 2, still)"
riscv dmi_write 0x16 0x700

# 4) aarsize=1 (16-bit) with transfer=1 write of x6 --> unsupported size --> cmderr=2.
#    Clear cmderr afterward. x6 must still be the .S sentinel (step 6).
riscv dmi_write 0x17 [aar 1 1 1 0x1006]
message "4 aarsize=1 write x6: abstractcs=[riscv dmi_read 0x16] (expect cmderr 2)"
riscv dmi_write 0x16 0x700

# 5) aarsize=4 (128-bit) with transfer=1 read of x5 --> unsupported size --> cmderr=2.
#    Neither data0 nor data1 may change. Clear cmderr afterward.
riscv dmi_write 0x17 [aar 4 1 0 0x1005]
message "5 aarsize=4 read x5: abstractcs=[riscv dmi_read 0x16] (expect cmderr 2)"
message "5 data0=[riscv dmi_read 0x04] (expect 0xa5a5a5a5, unchanged)"
message "5 data1=[riscv dmi_read 0x05] (expect 0xcafef00d, unchanged)"
riscv dmi_write 0x16 0x700

# 6) Happy-path XLEN-sized AAR:
#    - read x5 --> data holds the .S constant (rv64: data1:data0 = 0x11223344_55667788)
#    - read x6 --> still 0x0bad… (steps 1 and 4 must not have written)
#    - read x7 --> still 0x0badf00d… (sticky cmderr in step 3 blocked the write)
#    - write then read back x6 with 0x600dc0de to prove a real transfer works
riscv dmi_write 0x17 [aar $SZ 1 0 0x1005]
message "6 read x5: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "6 data0=[riscv dmi_read 0x04] (expect 0x55667788)"
if {!$ISA32} {
    message "6 data1=[riscv dmi_read 0x05] (expect 0x11223344)"
}
riscv dmi_write 0x17 [aar $SZ 1 0 0x1006]
message "6 read x6: data0=[riscv dmi_read 0x04] (expect 0x0bad0bad, steps 1/4 did not write)"
riscv dmi_write 0x17 [aar $SZ 1 0 0x1007]
message "6 read x7: data0=[riscv dmi_read 0x04] (expect 0x0badf00d, sticky cmderr held)"

riscv dmi_write 0x04 0x600dc0de
riscv dmi_write 0x05 0x00000000
riscv dmi_write 0x17 [aar $SZ 1 1 0x1006]
riscv dmi_write 0x04 0x00000000
riscv dmi_write 0x17 [aar $SZ 1 0 0x1006]
message "6 write/read x6: data0=[riscv dmi_read 0x04] (expect 0x600dc0de)"

# 7) Issue a legal AAR while the hart is running --> cmderr=4 (halt/resume).
#    Clear cmderr, halt, park dpc at test_end, resume so the .S can exit cleanly.
resume
riscv dmi_write 0x17 [aar $SZ 1 0 0x1005]
message "7 AAR while running: abstractcs=[riscv dmi_read 0x16] (expect cmderr 4)"
riscv dmi_write 0x16 0x700

halt
set_reg [list dpc $test_end]
resume
