######################################################################
# Receives the following arguments when called from debugtestgen.py
# ISA32      [32/64]
# BUILD_DIR  [build32/build]
# TEST_NAME  [WALLY-debug-******]
#
# dcsr.cause priority (Spec tab:dcsrcausepriority), highest first:
#   5 resethaltreq, 6 halt group, 3 haltreq, 2 trigger, 1 ebreak, 4 step
#
# Cases covered (Spike-reproducible):
#   1) haltreq alone               -> cause 3
#   2) step alone                  -> cause 4
#   3) ebreak vs step              -> cause 1 (ebreak beats step)
#
# Not covered here, because Spike cannot produce a reference .tv:
#   - resethaltreq: Spike does not implement setresethaltreq
#     (dmstatus.hasresethaltreq = 0); the hart runs out of reset and
#     onlyhalts on a later haltreq, so it would report cause 3.
#   - haltreq vs step / haltreq vs ebreak: the only DMI-level way to
#     overlap them is resumereq with haltreq set. The Spec says
#     resumereq is ignored while haltreq is set; Spike resumes anyway
#     and samples haltreq only between step() batches, so it reports
#     step (4) / ebreak (1). A spec-compliant hart must not match it.
#   Those need a testbench-side haltreq injection, not a Spike .tv.
######################################################################
log_output "${BUILD_DIR}/log/${TEST_NAME}.log"
debug_level 3
init
poll off

######################################################################
# Utility functions
######################################################################

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

proc read_reg {register} {
    set regval [lindex [reg $register] 2]
    return [expr {$regval}]
}

proc message {STR} {
    global TEST_NAME
    echo "$TEST_NAME: $STR"
    # echo $STR
}

proc dcsr_cause {} {
    return [expr {([read_reg dcsr] >> 6) & 7}]
}

proc clear_haltreq {} {
    # Absolute write (dmactive only). A read-modify-write of dmcontrol
    # can carry a stale resumereq back on Spike and resume the hart.
    riscv dmi_write 0x10 1
}

# Clear any previous abstract command error (cmderr is W1C in bits 10:8)
proc clear_abstract_error {} {
    riscv dm_write 0x16 0x700
}

# OpenOCD doesn't have a native way of performing an Abstract Register Command
# read and then immediately performing a write from whatever is in Data0 and
# Data1. Using this method, we don't have to rely on the data being written by
# the JTAG testvectors and can read and write to Wally from whatever is
# currently happening in the Hart. For example, DCSR can be read into Data0 and
# written into a GPR, which can then be written to the test signature. The
# Debugger doesn't need to know what the value of DCSR is in this case.
# proc aar_command_write {regno {size 64}} {
#     clear_abstract_error

#     if {$size == 64} {
#         set aarsize 3
#     } elseif {$size == 32} {
#         set aarsize 2
#     } else {
#         return -code error "size must be 32 or 64"
#     }

#     # Access Register: cmdtype=0, aarsize, postinc=0, postexec=0, transfer=1, write=1, regno
#     set command [expr {($aarsize << 20) | (1 << 17) | (1 << 16) | ($regno & 0xffff)}]

#     # This uses whatever is already in data0/data1
#     riscv dm_write 0x17 $command
# }

# # This should initiate a read into the data0 and data1 registers.
# proc aar_command_read {regno {size 64}} {
#     clear_abstract_error

#     if {$size == 64} {
#         set aarsize 3
#     } elseif {$size == 32} {
#         set aarsize 2
#     } else {
#         return -code error "size must be 32 or 64"
#     }

#     # Access Register: cmdtype=0, aarsize, postinc=0, postexec=0, transfer=1, write=1, regno
#     set command [expr {($aarsize << 20) | (1 << 17) | (0 << 16) | ($regno & 0xffff)}]

#     # This uses whatever is already in data0/data1
#     riscv dm_write 0x17 $command
# }

# Name to abstract regno for GPRs
array set gpr_abstract {
    zero 0x1000
    ra   0x1001
    sp   0x1002
    gp   0x1003
    tp   0x1004
    t0   0x1005
    t1   0x1006
    t2   0x1007
    s0   0x1008
    fp   0x1008
    s1   0x1009
    a0   0x100a
    a1   0x100b
    a2   0x100c
    a3   0x100d
    a4   0x100e
    a5   0x100f
    a6   0x1010
    a7   0x1011
    s2   0x1012
    s3   0x1013
    s4   0x1014
    s5   0x1015
    s6   0x1016
    s7   0x1017
    s8   0x1018
    s9   0x1019
    s10  0x101a
    s11  0x101b
    t3   0x101c
    t4   0x101d
    t5   0x101e
    t6   0x101f
    dcsr 0x07b0
    dpc  0x07b1
    mtvec 0x
}

# Name to abstract regno for FPRs
array set fpr_abstract {
    ft0  0x1020
    ft1  0x1021
    ft2  0x1022
    ft3  0x1023
    ft4  0x1024
    ft5  0x1025
    ft6  0x1026
    ft7  0x1027
    fs0  0x1028
    fs1  0x1029
    fa0  0x102a
    fa1  0x102b
    fa2  0x102c
    fa3  0x102d
    fa4  0x102e
    fa5  0x102f
    fa6  0x1030
    fa7  0x1031
    fs2  0x1032
    fs3  0x1033
    fs4  0x1034
    fs5  0x1035
    fs6  0x1036
    fs7  0x1037
    fs8  0x1038
    fs9  0x1039
    fs10 0x103a
    fs11 0x103b
    ft8  0x103c
    ft9  0x103d
    ft10 0x103e
    ft11 0x103f
}

# Name to abstract regno for common CSRs
# (abstract regno == CSR number)
array set csr_abstract {
    # Floating-point control/status
    fflags  0x001
    frm     0x002
    fcsr    0x003

    # Supervisor
    sstatus 0x100
    sie     0x104
    stvec   0x105
    scounteren 0x106
    sscratch 0x140
    sepc    0x141
    scause  0x142
    stval   0x143
    sip     0x144
    satp    0x180

    # Machine
    mstatus 0x300
    misa    0x301
    medeleg 0x302
    mideleg 0x303
    mie     0x304
    mtvec   0x305
    mcounteren 0x306
    mscratch 0x340
    mepc    0x341
    mcause  0x342
    mtval   0x343
    mip     0x344

    # Debug
    dcsr    0x7b0
    dpc     0x7b1
    dscratch0 0x7b2
    dscratch1 0x7b3

    # Triggers (common)
    tselect 0x7a0
    tdata1  0x7a1
    tdata2  0x7a2
    tdata3  0x7a3
    tinfo   0x7a4

    # Performance counters (examples)
    cycle   0xc00
    time    0xc01
    instret 0xc02
    mcycle  0xb00
    minstret 0xb02
}

proc get_regno {name} {
    global gpr_abstract
    global fpr_abstract
    global csr_abstract

    if {[info exists gpr_abstract($name)]} {
        return $gpr_abstract($name)
    } elseif {[info exists fpr_abstract($name)]} {
        return $fpr_abstract($name)
    } elseif {[info exists csr_abstract($name)]} {
        return $csr_abstract($name)
    }

    return -code error "unknown register name '$name'"
}

proc aar_command {reg_name {size 64} {write 0}} {
    clear_abstract_error

    set regno [get_regno $reg_name]

    if {$size == 64} {
        set aarsize 3
    } elseif {$size == 32} {
        set aarsize 2
    } else {
        return -code error "size must be 32 or 64"
    }

    # Access Register: cmdtype=0, aarsize, postinc=0, postexec=0, transfer=1, write=1, regno
    set command [expr {($aarsize << 20) | (1 << 17) | ($write << 16) | ($regno & 0xffff)}]

    # This uses whatever is already in data0/data1
    riscv dm_write 0x17 $command
}

# --------------------------------------------------------------------
# Set up tests
# --------------------------------------------------------------------

set objdump_file "${BUILD_DIR}/${TEST_NAME}.elf.objdump"
set park           [get_address $objdump_file park]
set do_nop         [get_address $objdump_file do_nop]
set do_ebreak      [get_address $objdump_file do_ebreak]
set test_end       [get_address $objdump_file test_end]
set write_cause    [get_address $objdump_file write_cause]

proc run_write_cause {} {
    global write_cause
    # Read DCSR into Data0 -> write Data0 into t4 -> record cause to signature
    aar_command dcsr 32 0
    aar_command t4   32 1
    set_reg [list dpc $write_cause]
    resume
    halt
    message "t4: [read_reg t4]"
    message "t5: [read_reg t5]"
}

# --------------------------------------------------------------------
# Begin tests
# --------------------------------------------------------------------

# Configures for halting at ebreak
reset halt
riscv.cpu configure -ebreak halt
clear_haltreq
resume

# Haltreq cause test -----------------------------------------------------------
# Halt at the first park loop
halt
message "PC: [read_reg pc]"

# Cause should be Halt = 3
run_write_cause

# Step cause test --------------------------------------------------------------
set_reg [list dpc $do_nop]
step
message "PC: [read_reg pc]"

# Cause should be Step = 4
run_write_cause

# EBreak cause test-------------------------------------------------------------
set_reg [list dpc $do_ebreak]
step
step
message "PC: [read_reg pc]"

# Cause should be EBreak = 1
run_write_cause

# Finish test ------------------------------------------------------------------
set_reg [list dpc $test_end]

resume
