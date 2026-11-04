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

# dmcontrol (0x10): [31] haltreq (WARZ), [30] resumereq, [1] ndmreset, [0] dmactive
# The testbench knownExceptions ignores dmcontrol[31:30] (Spike reads haltreq back as 1).
# dmstatus  (0x11): compared on [31:6] and [4]; version/hasresethaltreq are forgiven.
#
# While dmactive=0 the only DM register this test touches is dmcontrol.
# Wally returns 0 for every read while inactive and drops every non-dmcontrol
# write; Spike keeps serving data/command/abstractcs normally. Spec allows
# either ("Any accesses to the module may fail"), so those accesses would not
# replay cleanly and are left out.

# --------------------------------------------------------------------
# Begin test
# --------------------------------------------------------------------

halt

# 1) Baseline with dmactive=1: DM is usable.
#    dmcontrol reads back dmactive=1, hart reports halted, AAR read of x5 works.
message "1 dmcontrol=[riscv dmi_read 0x10] (expect 0x00000001)"
message "1 dmstatus=[riscv dmi_read 0x11] (expect allhalted/anyhalted, bits\[9:8\]=11)"
riscv dmi_write 0x17 [aar $SZ 1 0 0x1005]
message "1 read x5: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "1 data0=[riscv dmi_read 0x04] (expect 0x55667788)"
if {!$ISA32} {
    message "1 data1=[riscv dmi_read 0x05] (expect 0x11223344)"
}

# 2) Leave state behind that a DM reset must wipe out:
#    - haltreq=1 on an already-halted hart. haltreq is WARZ, so Wally reads
#      back 0x00000001; Spike reads 0x80000001 (bit 31 forgiven by the testbench).
#    - Sticky cmderr=2 from an aarsize=0 transfer. Deliberately NOT cleared.
riscv dmi_write 0x10 0x80000001
message "2 haltreq=1: dmcontrol=[riscv dmi_read 0x10] (expect 0x00000001, haltreq WARZ)"
riscv dmi_write 0x17 [aar 0 1 0 0x1005]
message "2 aarsize=0 read x5: abstractcs=[riscv dmi_read 0x16] (expect cmderr 2, left sticky)"

# 3) Deassert dmactive by writing 0 to dmcontrol (Spec's reset sequence:
#    write 0, poll until dmactive reads 0). Every other dmcontrol bit must
#    read back at its reset value. Only dmcontrol is read while inactive.
riscv dmi_write 0x10 0x00000000
message "3 dmactive=0: dmcontrol=[riscv dmi_read 0x10] (expect 0x00000000)"

# 4) Reassert dmactive and confirm the DM came back fresh:
#    - dmcontrol = dmactive only
#    - abstractcs cmderr cleared by the DM reset (no W1C was issued)
#    - hart still halted (DM reset must not resume or reset the hart here)
#    - module works again: AAR read of x6 returns the .S sentinel, and an
#      AAR write of x7 lands (read back in step 6 after a second DM reset)
riscv dmi_write 0x10 0x00000001
message "4 dmactive=1: dmcontrol=[riscv dmi_read 0x10] (expect 0x00000001)"
message "4 abstractcs=[riscv dmi_read 0x16] (expect cmderr 0, cleared by DM reset)"
message "4 dmstatus=[riscv dmi_read 0x11] (expect still halted, bits\[9:8\]=11)"
riscv dmi_write 0x17 [aar $SZ 1 0 0x1006]
message "4 read x6: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "4 data0=[riscv dmi_read 0x04] (expect 0x0bad0bad)"
if {!$ISA32} {
    message "4 data1=[riscv dmi_read 0x05] (expect 0x0bad0bad)"
}
riscv dmi_write 0x04 0x600dc0de
riscv dmi_write 0x05 0x00000000
riscv dmi_write 0x17 [aar $SZ 1 1 0x1007]
message "4 write x7: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"

# 5) Second cycle, this time deasserting with junk in the same write.
#    - Set sticky cmderr=2 again (aarsize=1).
#    - Write dmcontrol=0x80000000 (haltreq=1, dmactive=0): Spec says the DM
#      may ignore the other bits in the write that clears dmactive.
#    - While inactive, write dmcontrol=0x00000002 (ndmreset=1, dmactive=0).
#      Spec: dmactive is the only bit that can leave its reset value while
#      inactive, so ndmreset must read 0 and no system reset may happen
#      (x7 surviving in step 6 shows the hart was not reset).
riscv dmi_write 0x17 [aar 1 1 0 0x1005]
message "5 aarsize=1 read x5: abstractcs=[riscv dmi_read 0x16] (expect cmderr 2, left sticky)"
riscv dmi_write 0x10 0x80000000
message "5 haltreq + dmactive=0: dmcontrol=[riscv dmi_read 0x10] (expect 0x00000000)"
riscv dmi_write 0x10 0x00000002
message "5 ndmreset while inactive: dmcontrol=[riscv dmi_read 0x10] (expect 0x00000000, ndmreset ignored)"

# 6) Reassert and check again: fresh dmcontrol/abstractcs, ndmresetpending=0,
#    hart still halted, and the x7 value written in step 4 survived both
#    DM resets. Finish with an x5 read to show the full transfer path works.
riscv dmi_write 0x10 0x00000001
message "6 dmactive=1: dmcontrol=[riscv dmi_read 0x10] (expect 0x00000001)"
message "6 abstractcs=[riscv dmi_read 0x16] (expect cmderr 0, cleared by DM reset)"
message "6 dmstatus=[riscv dmi_read 0x11] (expect halted, ndmresetpending bit\[24\]=0)"
riscv dmi_write 0x17 [aar $SZ 1 0 0x1007]
message "6 read x7: abstractcs=[riscv dmi_read 0x16] (expect cmderr 0)"
message "6 data0=[riscv dmi_read 0x04] (expect 0x600dc0de, survived DM resets)"
riscv dmi_write 0x17 [aar $SZ 1 0 0x1005]
message "6 read x5: data0=[riscv dmi_read 0x04] (expect 0x55667788)"
if {!$ISA32} {
    message "6 data1=[riscv dmi_read 0x05] (expect 0x11223344)"
}

# Hart is still halted and OpenOCD still believes so (poll off, no
# resume issued), so no extra halt here. Park dpc at test_end and resume.
set_reg [list dpc $test_end]
resume
