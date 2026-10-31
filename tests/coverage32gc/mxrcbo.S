///////////////////////////////////////////
// mxrcbo.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: Sv32 coverage for permission checks that depend on sstatus.MXR, and for a non-leaf
//          page fault on an AMO.  RV32 counterpart of tests/coverage64gc/svadumxr.S plus parts of
//          tlbmisc.S and nonleafpbmtfault.S.
//          1. With menvcfg.ADUE = 1, a load from an execute-only page misses in the DTLB and the
//             walker judges the leaf with InvalidRead = ReadAccess & ~Readable & (~MXR | ~Executable)
//             (hptw.sv).  With MXR clear the load page-faults; with MXR set the same load is allowed.
//          2. cbo.clean needs read permission, or execute permission with MXR (tlbcontrol.sv
//             InvalidCBOM).  With MXR set, cbo.clean on the execute-only page is allowed, and
//             cbo.clean on a page with W = 1 and R = X = 0 (a reserved encoding) takes a store/AMO
//             page fault.
//          3. A non-leaf PTE with A, D or U set is reserved and makes the walk fault (hptw.sv
//             DAUFaultM).  An AMO through such a PTE takes a store/AMO page fault: the walker's
//             fault is classed by MemRWM = 2'b11 (hptw.sv HPTWStoreAmoPageFault).
//          Self-checking (WALLY-selfcheck.h): every page fault is logged (mcause, mepc, mtval) and the
//          log is compared with the expected list at the end; values loaded and the AMO's memory word
//          are checked.  Failure indices: 1-6 values, 10 trap count, 11+ log entries, 0xF0 another trap.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// address of the level-0 Sv32 PTE that maps a label, into reg (clobbers t6)
.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x3FF
    slli \reg, \reg, 2
    la t6, l0table
    add \reg, \reg, t6
.endm

// ROOT_NONLEAF vpn1, flags: root entry vpn1 points to l0table with the given extra flags (V is added)
.macro ROOT_NONLEAF vpn1, flags
    la t0, roottable
    li t2, \vpn1 * 4
    add t0, t0, t2
    la t1, l0table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1 | \flags
    sw t1, 0(t0)
.endm

// EXPECT cause, mepc_label, mtval_reg: append an expected trap to the expected list (clobbers t0, t1)
.macro EXPECT cause, epc, tval
    lw t0, nexp
    slli t0, t0, 4
    la t1, explog
    add t0, t0, t1
    li t1, \cause
    sw t1, 0(t0)
    la t1, \epc
    sw t1, 4(t0)
    sw \tval, 8(t0)
    lw t0, nexp
    addi t0, t0, 1
    sw t0, nexp, t1
.endm

main:
    la t0, record_trap
    csrw mtvec, t0

    // Identity-map the first 4 MiB of RAM with 4 KiB pages (Sv32: root -> level 0)
    la t0, l0table
    li t1, 0x80000              # PPN of 0x80000000
    li t2, 1024
build_l0:
    slli t3, t1, 10
    ori t3, t3, 0xCF            # V R W X A D
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, build_l0
    ROOT_NONLEAF 0x200, 0       # VA 0x80000000-0x803FFFFF
    // Aliases of the same 4 MiB through non-leaf root PTEs with a reserved bit set
    ROOT_NONLEAF 0x100, 0x40    # VA 0x40000000: A set
    ROOT_NONLEAF 0x101, 0x80    # VA 0x40400000: D set
    ROOT_NONLEAF 0x102, 0x10    # VA 0x40800000: U set

    // xo_page is execute-only: clear R and W.  wo_page has W = 1, R = X = 0 (reserved).
    L0_ENTRY xo_page, t0
    lw t1, 0(t0)
    andi t1, t1, -7             # ~(R | W)
    sw t1, 0(t0)
    L0_ENTRY wo_page, t0
    lw t1, 0(t0)
    andi t1, t1, -12            # ~(R | X)
    sw t1, 0(t0)

    // Data for the loads below, written while translation is still off
    la a1, xo_page
    li t0, 0xCAFEBEEF
    sw t0, 0(a1)
    la a2, amo_word
    li t0, 0x11111111
    sw t0, 0(a2)

    li t0, 1
    slli t0, t0, 29             # menvcfgh.ADUE (menvcfg bit 61): hardware updates A and D
    csrs menvcfgh, t0
    li t0, 0xF0                 # menvcfg.CBZE, CBCFE, CBIE: supervisor mode may use the CMOs
    csrs menvcfg, t0
    la t0, roottable
    srli t0, t0, 12
    li t1, 0x80000000           # MODE = 1, Sv32
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    // 1. MXR clear: the load from the execute-only page misses in the DTLB, the walker finds a leaf
    // that is readable only under MXR, and the load page-faults; the handler steps over it.
    li t1, 0
xo_load0:
    lw t1, 0(a1)
    SC_CHECK_EQ t1, zero, 1     # the faulting load wrote nothing

    // MXR set: after an sfence.vma the same load misses again and is allowed this time
    li t0, 1
    slli t0, t0, 19             # sstatus.MXR
    csrs sstatus, t0
    sfence.vma
    lw t1, 0(a1)
    li t2, 0xCAFEBEEF
    SC_CHECK_EQ t1, t2, 2

    // 2. MXR set: cbo.clean on the execute-only page is allowed, on the W-only page it faults
    sfence.vma
    cbo.clean (a1)              # walks (DTLB miss), then hits
    cbo.clean (a1)
    la a3, wo_page
wo_clean:
    cbo.clean (a3)
    csrc sstatus, t0            # MXR clear again

    // 3. AMOs, a store and a load through non-leaf PTEs with A, D or U set: each walk faults
    la t0, amo_word
    li t1, 0x80000000
    sub s4, t0, t1              # offset of amo_word in the 4 MiB region
    li t1, 0x40000000
    add s5, s4, t1              # through the A alias
    li t1, 0x40400000
    add s6, s4, t1              # through the D alias
    li t1, 0x40800000
    add s7, s4, t1              # through the U alias
    li t3, 5
amo_a:
    amoadd.w t2, t3, (s5)
amo_d:
    amoadd.w t2, t3, (s6)
amo_u:
    amoswap.w t2, t3, (s7)
st_a:
    sw t3, 0(s5)
ld_u:
    lw t2, 0(s7)
    // The same word through the normal mapping: the AMO works and the word was not changed before
    amoadd.w t2, t3, (a2)
    li t1, 0x11111111
    SC_CHECK_EQ t2, t1, 3
    lw t2, 0(a2)
    li t1, 0x11111116
    SC_CHECK_EQ t2, t1, 4

    li a0, 3
    ecall                       # machine mode
    csrw satp, zero
    sfence.vma
    li t0, 0xF0
    csrc menvcfg, t0
    li t0, 1
    slli t0, t0, 29
    csrc menvcfgh, t0

    // Expected traps, in order
    la a4, xo_page
    EXPECT 13, xo_load0, a4     # load page fault: execute-only page, MXR clear
    la a4, wo_page
    EXPECT 15, wo_clean, a4     # store/AMO page fault: cbo.clean on the W-only page
    EXPECT 15, amo_a, s5        # store/AMO page faults from the non-leaf PTEs
    EXPECT 15, amo_d, s6
    EXPECT 15, amo_u, s7
    EXPECT 15, st_a, s5
    EXPECT 13, ld_u, s7         # load page fault

    lw t2, ntrap
    lw t3, nexp
    SC_CHECK_EQ t2, t3, 10
    la a4, traplog
    la a5, explog
    li a6, 0
cmploop:
    beq a6, t3, cmpdone
    lw t4, 0(a4)
    lw t5, 0(a5)
    SC_CHECK_EQ_ADR t4, t5, a6, 11  # mcause
    lw t4, 4(a4)
    lw t5, 4(a5)
    SC_CHECK_EQ_ADR t4, t5, a6, 12  # mepc
    lw t4, 8(a4)
    lw t5, 8(a5)
    SC_CHECK_EQ_ADR t4, t5, a6, 13  # mtval
    addi a4, a4, 16
    addi a5, a5, 16
    addi a6, a6, 1
    j cmploop
cmpdone:
    SC_PASS
    j done

// Load (13) and store/AMO (15) page faults: log mcause, mepc and mtval in traplog, then let the
// library handler skip the instruction.  Everything else goes to sc_trap_handler, which passes ecalls
// to the library handler and fails the test on any other trap.
.align 4
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sw t1, -12(t0)
    sw t2, -16(t0)
    csrr t2, mcause
    addi t2, t2, -13
    beqz t2, 1f
    addi t2, t2, -2
    beqz t2, 1f
    lw t2, -16(t0)
    lw t1, -12(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j sc_trap_handler
1:  sw t3, -20(t0)
    la t1, ntrap
    lw t2, 0(t1)
    addi t3, t2, 1
    sw t3, 0(t1)
    slli t2, t2, 4
    la t1, traplog
    add t1, t1, t2
    csrr t2, mcause
    sw t2, 0(t1)
    csrr t2, mepc
    sw t2, 4(t1)
    csrr t2, mtval
    sw t2, 8(t1)
    lw t3, -20(t0)
    lw t2, -16(t0)
    lw t1, -12(t0)
    csrrw t0, mscratch, t0
    j trap_handler

.data
.p2align 12
roottable:
    .fill 1024, 4, 0
l0table:
    .fill 1024, 4, 0
xo_page:
    .fill 1024, 4, 0
wo_page:
    .fill 1024, 4, 0
amo_word:
    .word 0
.align 2
ntrap:
    .word 0
nexp:
    .word 0
traplog:
    .fill 16*4, 4, 0
explog:
    .fill 16*4, 4, 0
