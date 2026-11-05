######################################################################
# dmrun.tcl: helpers for the DM run-control rule tests (area "dmrun":
# dmcontrol, dmstatus, hart states, halt/resume, resethaltreq,
# havereset, ndmreset, dmactive, hart selection, hartinfo, haltsum,
# dmcs2, confstrptr, nextdm). Source after rules.tcl.
######################################################################

# Extra DM register addresses
set DM_CONFSTRPTR1 0x1a
set DM_CONFSTRPTR2 0x1b
set DM_CONFSTRPTR3 0x1c
set DM_CUSTOM 0x1f

# dmcontrol bits
set HALTREQ        [expr {1 << 31}]
set RESUMEREQ      [expr {1 << 30}]
set HARTRESET      [expr {1 << 29}]
set ACKHAVERESET   [expr {1 << 28}]
set ACKUNAVAIL     [expr {1 << 27}]
set HASEL          [expr {1 << 26}]
set HARTSELLO      [expr {0x3ff << 16}]
set HARTSELHI      [expr {0x3ff << 6}]
set SETKEEPALIVE   [expr {1 << 5}]
set CLRKEEPALIVE   [expr {1 << 4}]
set SETRESETHALTREQ [expr {1 << 3}]
set CLRRESETHALTREQ [expr {1 << 2}]
set NDMRESET       [expr {1 << 1}]
set DMACTIVE       1

# dmstatus bits (rules.tcl defines ALLHALTED, ALLRUNNING, ALLRESUMEACK,
# ALLHAVERESET)
set NDMRESETPENDING [expr {1 << 24}]
set STICKYUNAVAIL  [expr {1 << 23}]
set IMPEBREAK      [expr {1 << 22}]
set ANYHAVERESET   [expr {1 << 18}]
set ANYRESUMEACK   [expr {1 << 16}]
set ALLNONEXISTENT [expr {1 << 15}]
set ANYNONEXISTENT [expr {1 << 14}]
set ALLUNAVAIL     [expr {1 << 13}]
set ANYUNAVAIL     [expr {1 << 12}]
set ANYRUNNING     [expr {1 << 10}]
set ANYHALTED      [expr {1 << 8}]
set AUTHENTICATED  [expr {1 << 7}]
set AUTHBUSY       [expr {1 << 6}]
set HASRESETHALTREQ [expr {1 << 5}]
set CONFSTRPTRVALID [expr {1 << 4}]

# Hart-state bits of dmstatus: all/any of nonexistent, unavail,
# running, halted (15:8).
set HARTSTATE_MASK 0x0000ff00
# Hart state 15:8 for a running / halted existing hart
set STATE_RUNNING  0x00000c00
set STATE_HALTED   0x00000300
# havereset and resumeack (19:16)
set HAVERESET_MASK [expr {(1 << 19) | (1 << 18)}]
set RESUMEACK_MASK [expr {(1 << 17) | (1 << 16)}]

# Write dmcontrol with dmactive set
proc dmc_wr {value} {
    global DM_DMCONTROL
    dmi_wr $DM_DMCONTROL [expr {$value | 1}]
}

# Halt robustly. Spike keeps a resume request written to a running hart
# and resumes the hart right after its next halt (Spike deviation from
# dm_resume_request_ignored_running), so a test that wrote resumereq to
# a running hart halts twice to leave Spike halted too. On Wally the
# second halt is a no-op (halted harts ignore haltreq).
proc halt_hart_twice {} {
    halt_hart
    halt_hart
}

# Wait until the hart runs (unchecked polling).
proc wait_running {} {
    global DM_DMSTATUS ALLRUNNING
    poll_until $DM_DMSTATUS $ALLRUNNING $ALLRUNNING
}

# Wait until the hart halts (unchecked polling).
proc wait_halted {} {
    global DM_DMSTATUS ALLHALTED
    poll_until $DM_DMSTATUS $ALLHALTED $ALLHALTED
}

# Pulse ndmreset; extra holds bits (such as haltreq) written with both
# writes. Unchecked.
proc ndmreset_pulse {{extra 0}} {
    global NDMRESET
    dmc_wr [expr {$extra | $NDMRESET}]
    dmc_wr $extra
}

# Acknowledge havereset.
proc ack_havereset {} {
    global ACKHAVERESET
    dmc_wr $ACKHAVERESET
}

# Set / clear the halt-on-reset request of the selected hart.
proc set_resethaltreq {} {
    global SETRESETHALTREQ
    dmc_wr $SETRESETHALTREQ
}
proc clr_resethaltreq {} {
    global CLRRESETHALTREQ
    dmc_wr $CLRRESETHALTREQ
}

# Deactivate and reactivate the DM. first is the value written to
# dmcontrol to deactivate (dmactive must be 0 in it). Polls dmactive
# (unchecked) after each write.
proc dm_reset {{first 0}} {
    global DM_DMCONTROL
    dmi_wr $DM_DMCONTROL $first
    poll_until $DM_DMCONTROL 1 0
    dmi_wr $DM_DMCONTROL 1
    poll_until $DM_DMCONTROL 1 1
}

# Read a DM register that Spike does not implement. Spike answers with
# a failed DMI op; OpenOCD reports an error, which is caught here. The
# response can then be checked against the spec value with
# tv_check_failed.
proc dmi_rd_unimp {addr} {
    if {[catch {set v [dmi_rd $addr]} err]} {
        echo "dmi_rd_unimp $addr: $err"
        return 0
    }
    return $v
}
proc dmi_wr_unimp {addr value} {
    if {[catch {dmi_wr $addr $value} err]} {
        echo "dmi_wr_unimp $addr: $err"
    }
}

# Abstract-access register numbers
set REG_DCSR 0x7b0
set REG_DPC  0x7b1
set REG_S1   0x1009
set REG_A0   0x100a

# Size of an XLEN-wide abstract access (2 = 32 bits, 3 = 64 bits)
proc xsize {} {
    global ISA32
    return [expr {3 - $ISA32}]
}
