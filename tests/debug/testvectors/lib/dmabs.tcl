######################################################################
# dmabs.tcl: helpers for the abstract-command / DM data-path rule tests
#
# Source after rules.tcl. The dmabs tests share one program: every
# GPR x1-x31 and FPR f0-f31 holds a known pattern (gpr_val/fpr_val below) and mscratch holds MSCRATCH;
# at test_end the program stores x0-x31 and f0-f31 to the signature,
# so any register the debugger changed is checked against Spike.
######################################################################

# aarsize of a full GPR/CSR (2 on RV32, 3 on RV64). FPRs are 64-bit (D).
set XSZ [expr {3 - $ISA32}]

proc gpr {n} { return [expr {0x1000 + $n}] }
proc fpr {n} { return [expr {0x1020 + $n}] }

# Initial register values set by templates/dmabs_regs.S
proc gpr_val {n} {
    global ISA32
    if {$ISA32} { return [expr {($n << 24) | (0x5a << 16) | ($n << 8) | 0xa5}] }
    return [expr {($n << 56) | (0x11 << 48) | ($n << 40) | (0x22 << 32) |
                  ($n << 24) | (0x33 << 16) | ($n << 8) | 0x44}]
}
proc fpr_val {n} {
    return [expr {($n << 56) | (0x66 << 48) | ($n << 40) | (0x77 << 32) |
                  ($n << 24) | (0x88 << 16) | ($n << 8) | 0x99}]
}

# Write a raw command word and wait for busy to clear. The last DMI
# read is of abstractcs, so a tv_check of abstractcs right after this
# checks the completed command's status. Returns abstractcs.
proc cmd_wait {cmd} {
    global DM_COMMAND
    dmi_wr $DM_COMMAND $cmd
    return [wait_abstract]
}

# Check abstractcs.cmderr of the last abstractcs read (against Spike,
# or against the spec value v if given).
proc check_cmderr {args} {
    global DM_ABSTRACTCS
    if {[llength $args] == 0} {
        tv_check $DM_ABSTRACTCS 0x700
    } else {
        tv_check $DM_ABSTRACTCS 0x700 [expr {[lindex $args 0] << 8}]
    }
}

# Read data0 (and data1 for size 3) and check them against Spike.
proc check_data {size} {
    global DM_DATA0 DM_DATA1
    dmi_rd $DM_DATA0
    tv_check $DM_DATA0 0xffffffff
    if {$size == 3} {
        dmi_rd $DM_DATA1
        tv_check $DM_DATA1 0xffffffff
    }
}

# Put a 32- or 64-bit value into the arg0 region of data.
proc set_arg0 {size value} {
    global DM_DATA0 DM_DATA1
    dmi_wr $DM_DATA0 [expr {$value & 0xffffffff}]
    if {$size == 3} { dmi_wr $DM_DATA1 [expr {($value >> 32) & 0xffffffff}] }
}
