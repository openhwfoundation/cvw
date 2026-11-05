######################################################################
# sdext.tcl: helpers for the Sdext rule tests (hart-side rules:
# Debug Mode, dcsr, dpc, step, halt/resume). Source after rules.tcl.
# The programs use tests/debug/include/sdext.h.
######################################################################

set SZ [expr {3 - $ISA32}]
set XLEN [expr {$ISA32 ? 32 : 64}]
set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"

# CSR numbers (abstract regno == CSR address)
set CSR_DCSR      0x7b0
set CSR_DPC       0x7b1
set CSR_DSCRATCH0 0x7b2
set CSR_DSCRATCH1 0x7b3
set CSR_MSTATUS   0x300
set CSR_MEDELEG   0x302
set CSR_MIE       0x304
set CSR_MTVEC     0x305
set CSR_MSCRATCH  0x340
set CSR_MEPC      0x341
set CSR_MCAUSE    0x342
set CSR_MTVAL     0x343
set CSR_MIP       0x344
set CSR_MCYCLE    0xb00
set CSR_MINSTRET  0xb02

# dcsr fields
set DCSR_EBREAKVS  [expr {1 << 17}]
set DCSR_EBREAKVU  [expr {1 << 16}]
set DCSR_EBREAKM   [expr {1 << 15}]
set DCSR_EBREAKS   [expr {1 << 13}]
set DCSR_EBREAKU   [expr {1 << 12}]
set DCSR_STEPIE    [expr {1 << 11}]
set DCSR_STOPCOUNT [expr {1 << 10}]
set DCSR_STOPTIME  [expr {1 << 9}]
set DCSR_CAUSE     [expr {7 << 6}]
set DCSR_V         [expr {1 << 5}]
set DCSR_MPRVEN    [expr {1 << 4}]
set DCSR_NMIP      [expr {1 << 3}]
set DCSR_STEP      [expr {1 << 2}]
set DCSR_PRV       3
set DCSR_EBREAKALL [expr {(1 << 15) | (1 << 13) | (1 << 12)}]

# mstatus fields
set MSTATUS_MIE  [expr {1 << 3}]
set MSTATUS_MPP  [expr {3 << 11}]
set MSTATUS_MPRV [expr {1 << 17}]

# Abstract regno of a GPR given by ABI name or number
proc gpr {r} {
    set names {zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7
               s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6}
    set i [lsearch -exact $names $r]
    if {$i < 0} { set i $r }
    return [expr {0x1000 + $i}]
}

# Address of a program label
proc lbl {name} {
    global objdump_file
    return [get_address $objdump_file $name]
}

# XLEN-wide abstract register read/write
proc rd {regno} { global SZ; return [abs_read $regno $SZ] }
proc wr {regno value} { global SZ; return [abs_write $regno $SZ $value] }

# Compare the XLEN-wide value of the last rd: the mask bits of data0
# (and, on RV64, data1). With value, expect value's bits (spec value).
proc check_last {mask args} {
    global DM_DATA0 DM_DATA1 ISA32
    set lo [expr {$mask & 0xffffffff}]
    set hi [expr {($mask >> 32) & 0xffffffff}]
    if {$lo != 0} {
        if {[llength $args]} { tv_check $DM_DATA0 $lo [expr {[lindex $args 0] & 0xffffffff}] } else { tv_check $DM_DATA0 $lo }
    }
    if {!$ISA32 && $hi != 0} {
        if {[llength $args]} { tv_check $DM_DATA1 $hi [expr {([lindex $args 0] >> 32) & 0xffffffff}] } else { tv_check $DM_DATA1 $hi }
    }
}

# Read regno and compare the mask bits (default all XLEN bits).
# OpenOCD's Jim Tcl has 64-bit integers: -1 is the all-ones mask.
proc check_rd {regno {mask -1} args} {
    global ISA32
    if {$mask == -1 && $ISA32} { set mask 0xffffffff }
    set v [rd $regno]
    check_last $mask {*}$args
    return $v
}

# Read abstractcs and compare cmderr (with optional spec value).
proc check_cmderr {args} {
    global DM_ABSTRACTCS
    dmi_rd $DM_ABSTRACTCS
    tv_check $DM_ABSTRACTCS 0x700 {*}$args
}

# Read dmstatus and compare allhalted/anyhalted/allrunning/anyrunning.
proc check_halted {args} {
    global DM_DMSTATUS
    dmi_rd $DM_DMSTATUS
    tv_check $DM_DMSTATUS 0xf00 {*}$args
}

# dcsr value: prv plus named flags (ebreakm ebreaks ebreaku stepie
# stopcount step) or raw bit values.
proc dcsr_value {prv args} {
    set v $prv
    foreach f $args {
        switch -- $f {
            ebreakm   { set v [expr {$v | (1 << 15)}] }
            ebreaks   { set v [expr {$v | (1 << 13)}] }
            ebreaku   { set v [expr {$v | (1 << 12)}] }
            ebreakall { set v [expr {$v | (1 << 15) | (1 << 13) | (1 << 12)}] }
            stepie    { set v [expr {$v | (1 << 11)}] }
            stopcount { set v [expr {$v | (1 << 10)}] }
            step      { set v [expr {$v | (1 << 2)}] }
            default   { set v [expr {$v | $f}] }
        }
    }
    return $v
}
proc set_dcsr {prv args} {
    global CSR_DCSR
    wr $CSR_DCSR [dcsr_value $prv {*}$args]
}

# Wait for the hart to halt (dmstatus.allhalted); polling not compared.
proc sd_wait_halted {{max 400}} {
    global DM_DMSTATUS ALLHALTED
    return [poll_until $DM_DMSTATUS $ALLHALTED $ALLHALTED $max]
}

# Resume at address addr with dcsr = (prv, flags) and wait until the
# hart halts again (an ebreak with ebreak{m,s,u}=1, or a step).
proc sd_run {addr prv args} {
    global CSR_DPC
    set_dcsr $prv {*}$args
    wr $CSR_DPC $addr
    resume_hart
    sd_wait_halted
}

# Resume at addr with dcsr = (prv, flags) without waiting for a halt.
proc sd_go {addr prv args} {
    global CSR_DPC
    set_dcsr $prv {*}$args
    wr $CSR_DPC $addr
    resume_hart
}

# Halt the parked hart at the start of a test (allhalted not compared).
proc sd_begin {} {
    halt_hart
}

# End of test: M-mode, no step, resume at test_end, which stores the
# signature and writes tohost.
proc sd_finish {} {
    global CSR_DPC
    set_dcsr 3 ebreakall
    wr $CSR_DPC [lbl test_end]
    resume_hart
}
