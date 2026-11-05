######################################################################
# rules.tcl: helpers for the per-normative-rule debug tests
#
# Source this after "init; poll off". The TV_* echoes are directives
# for tv_from_log.py (see that file):
#   tv_rule              rule mode: only tv_check'ed reads are compared
#   tv_check a mask [v]  compare the mask bits of the last read of DM
#                        register a; with v, expect v's bits there (the
#                        spec value, where Spike's DM differs)
#   poll_until ...       polling whose length depends on timing is not
#                        compared
######################################################################

proc get_address {filename label} {
    if {[catch {set fd [open $filename r]} err]} {
        error "Couldn't open $filename: $err"
    }
    set regex "^(\[0-9a-fA-f\]+)\\s+<${label}>:"
    while {[gets $fd line] != -1} {
        if {[regexp $regex $line match address]} {
            close $fd
            return "0x[string range $address 0 15]"
        }
    }
    close $fd
    error "Label not found in $filename: $label"
}

proc tv_rule {} { echo "TV_RULE" }

proc tv_check {addr mask args} {
    if {[llength $args] == 0} {
        echo [format "TV_CHECK 0x%02x 0x%08x" $addr [expr {$mask & 0xffffffff}]]
    } else {
        echo [format "TV_CHECK 0x%02x 0x%08x 0x%08x" $addr [expr {$mask & 0xffffffff}] [expr {[lindex $args 0] & 0xffffffff}]]
    }
}

proc dmi_rd {addr} { return [riscv dmi_read $addr] }
proc dmi_wr {addr value} { riscv dmi_write $addr [format 0x%08x [expr {$value & 0xffffffff}]] }

# Read DM register addr until (value & mask) == want, at most max
# times, without comparing those reads; then read it once more.
# Returns the final value.
proc poll_until {addr mask want {max 200}} {
    echo "TV_DONTCARE_BEGIN"
    for {set i 0} {$i < $max} {incr i} {
        set v [dmi_rd $addr]
        if {($v & $mask) == $want} { break }
    }
    echo "TV_DONTCARE_END"
    return [dmi_rd $addr]
}

# DM register addresses
set DM_DATA0 0x04
set DM_DATA1 0x05
set DM_DMCONTROL 0x10
set DM_DMSTATUS 0x11
set DM_HARTINFO 0x12
set DM_HALTSUM1 0x13
set DM_HAWINDOWSEL 0x14
set DM_HAWINDOW 0x15
set DM_ABSTRACTCS 0x16
set DM_COMMAND 0x17
set DM_ABSTRACTAUTO 0x18
set DM_CONFSTRPTR0 0x19
set DM_NEXTDM 0x1d
set DM_PROGBUF0 0x20
set DM_AUTHDATA 0x30
set DM_DMCS2 0x32
set DM_HALTSUM2 0x34
set DM_HALTSUM3 0x35
set DM_SBADDRESS3 0x37
set DM_SBCS 0x38
set DM_SBADDRESS0 0x39
set DM_SBDATA0 0x3c
set DM_HALTSUM0 0x40

# dmstatus bits
set ALLHALTED   [expr {1 << 9}]
set ALLRUNNING  [expr {1 << 11}]
set ALLRESUMEACK [expr {1 << 17}]
set ALLHAVERESET [expr {1 << 19}]

# Halt hart 0 with raw DMI accesses and wait for allhalted.
proc halt_hart {} {
    global DM_DMCONTROL DM_DMSTATUS ALLHALTED
    dmi_wr $DM_DMCONTROL 0x80000001
    poll_until $DM_DMSTATUS $ALLHALTED $ALLHALTED
    dmi_wr $DM_DMCONTROL 0x00000001
}

# Resume hart 0 and wait for allresumeack.
proc resume_hart {} {
    global DM_DMCONTROL DM_DMSTATUS ALLRESUMEACK
    dmi_wr $DM_DMCONTROL 0x40000001
    poll_until $DM_DMSTATUS $ALLRESUMEACK $ALLRESUMEACK
    dmi_wr $DM_DMCONTROL 0x00000001
}

# Wait for abstractcs.busy to clear; returns abstractcs.
proc wait_abstract {} {
    global DM_ABSTRACTCS
    return [poll_until $DM_ABSTRACTCS [expr {1 << 12}] 0]
}

# Access Register command word. size is 2 (32-bit) or 3 (64-bit).
proc access_reg_cmd {regno size write {transfer 1}} {
    return [expr {($size << 20) | ($transfer << 17) | ($write << 16) | $regno}]
}

# Abstract register read; returns the value (data1:data0 for size 3).
proc abs_read {regno size} {
    global DM_COMMAND DM_DATA0 DM_DATA1
    dmi_wr $DM_COMMAND [access_reg_cmd $regno $size 0]
    wait_abstract
    set lo [dmi_rd $DM_DATA0]
    if {$size == 3} {
        set hi [dmi_rd $DM_DATA1]
        return [expr {($hi << 32) | $lo}]
    }
    return $lo
}

# Abstract register write.
proc abs_write {regno size value} {
    global DM_COMMAND DM_DATA0 DM_DATA1
    dmi_wr $DM_DATA0 [expr {$value & 0xffffffff}]
    if {$size == 3} { dmi_wr $DM_DATA1 [expr {($value >> 32) & 0xffffffff}] }
    dmi_wr $DM_COMMAND [access_reg_cmd $regno $size 1]
    return [wait_abstract]
}

# Clear abstractcs.cmderr (W1C).
proc clear_cmderr {} {
    global DM_ABSTRACTCS
    dmi_wr $DM_ABSTRACTCS [expr {7 << 8}]
}

# Leave the test: point dpc at label test_end (if given) and resume, so
# the program writes its signature and stops.
proc finish_test {objdump_file {size 3}} {
    set test_end [get_address $objdump_file test_end]
    abs_write 0x7b1 $size $test_end
    resume_hart
}
