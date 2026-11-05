///////////////////////////////////////////
// hptwchain.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: The page table walker receives a DTLB request and an ITLB request in the same cycle.  It
//          serves the DTLB walk first and, from LEAF, chains directly to the pending ITLB walk
//          (hptw.sv: LEAF, DTLBWalk & ITLBWalkPending).  Each code page starts with sfence.vma, which
//          flushes every non-global TLB entry, and ends with a load or store to a data page followed by
//          g = 1, 2 or 3 nops.  With g = 2 the access reaches the Memory stage in the cycle the fetch
//          moves to the first instruction of the next page, so the access's DTLB miss and the fetch's
//          ITLB miss arrive together.  The other gaps are kept so the test does not depend on a single
//          pipeline alignment.  Sv32, supervisor mode, the first 4 MiB of RAM identity-mapped with 4 KiB
//          pages.
//          Self-checking (WALLY-selfcheck.h): every load value and the stored word are checked after the
//          last page, each page increments s2 once, and SC_STRICT_TRAPS fails the test on any trap other
//          than an ecall.  Failure indices: 1 page count, 2-6 loads, 7 store, 0xF0 a trap.
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
.option norvc

#define PAT  0x6B6B0000             // word k of data_page holds PAT + k

// CPAGE g, instr: a 4096-byte code page: count it in s2, flush the TLBs, then nops so that instr is
// followed by g nops that end the page.
.macro CPAGE g, instr:vararg
    sfence.vma
    addi s2, s2, 1
    .rept 1021 - \g
    nop
    .endr
    \instr
    .rept \g
    nop
    .endr
.endm

main:
    SC_STRICT_TRAPS

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
    la t0, roottable
    la t1, l0table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1               # non-leaf
    li t2, 0x200*4
    add t0, t0, t2
    sw t1, 0(t0)                # root entry 0x200: VA 0x80000000-0x803FFFFF

    la t0, roottable
    srli t0, t0, 12
    li t1, 0x80000000           # MODE = 1, Sv32
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    la a2, data_page
    li s2, 0
    j cpages

.p2align 12
cpages:
    CPAGE 2, lw s3, 0(a2)
    CPAGE 2, lw s4, 64(a2)
    CPAGE 1, lw s5, 128(a2)
    CPAGE 3, lw s6, 192(a2)
    CPAGE 2, sw s3, 256(a2)
    CPAGE 2, lw s7, 260(a2)
    li a0, 3
    ecall

    li t2, 6
    SC_CHECK_EQ s2, t2, 1
    li t2, PAT + 0
    SC_CHECK_EQ s3, t2, 2
    li t2, PAT + 16
    SC_CHECK_EQ s4, t2, 3
    li t2, PAT + 32
    SC_CHECK_EQ s5, t2, 4
    li t2, PAT + 48
    SC_CHECK_EQ s6, t2, 5
    li t2, PAT + 65
    SC_CHECK_EQ s7, t2, 6
    lw t3, 256(a2)
    li t2, PAT + 0
    SC_CHECK_EQ t3, t2, 7

    SC_PASS
    j done

.data
.p2align 12
roottable:
    .fill 1024, 4, 0
l0table:
    .fill 1024, 4, 0
data_page:
    .set k, 0
    .rept 1024
    .word PAT + k
    .set k, k + 1
    .endr
