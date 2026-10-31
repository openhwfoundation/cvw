///////////////////////////////////////////
// holdaccess.S
//
// Written: David_Harris@hmc.edu 19 September 2026; RV32 Sv32 port 27 October 2026
//
// Purpose: RV32 port of the cacheable cases of tests/coverage64gc/holdaccess.S (rv32gc has no
//          Svpbmt, so the non-cacheable pages are left out).  A memory access completes while the
//          pipeline is stalled by an ITLB miss that arrived after the access started: the walker
//          then accepts the ITLB request with the access already performed (hptw.sv HPTWFlushW,
//          AcceptReq & MemAccessDoneM), and the LSU must hold the finished access until it
//          retires instead of reissuing it.  A 32-bit instruction straddling the page boundary
//          makes the ITLB miss appear late: its first half is fetched normally and its second
//          half, on the next page, is translated a cycle later, after the data access has left
//          the cache's idle state.  Each page here ends with a load or store that misses the data
//          cache, 2, 3 or 4 instructions before a straddling addi whose second half is on a page
//          that has just been flushed from the TLB.
//          Self-checking (WALLY-selfcheck.h), with every check after the last page so the sequences
//          keep their timing: each held access uses its own cache line, each held load writes its
//          own register, and the data starts with a nonzero pattern, so the test checks every
//          loaded value and every stored word.  The straddling instruction is addi s2, s2, 1, so s2
//          counts the 9 straddles.  SC_STRICT_TRAPS fails the test on any trap other than an ecall.
//          Failure indices: 1 straddle count, 2 warm-up load, 3-8 held loads, 9-12 stores, 0xF0 a trap.
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

#define COLD  0x5A5A0000            // word k of cold_lines holds COLD + k

// Code page ending in a straddling addi s2, s2, 1 (0x00190913).  The page starts with the high half
// of the previous page's straddle (hi), flushes the next page from the TLBs (sfence.vma flushes every
// non-global entry, so a load from the cached first line brings the data page back), and puts the access
// 2, 3 or 4 instructions before the straddle.  Every page is exactly 4096 bytes.
.macro PAGE3 hi, next, instr:vararg
    .half \hi
    la t5, \next
    sfence.vma t5               # flushes every non-global TLB entry (Wally ignores rs1)
    lw t4, -256(a2)             # bring the data page back into the DTLB (the line is cached)
    .rept 1016
    nop
    .endr
    \instr
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
.endm
.macro PAGE2 hi, next, instr:vararg
    .half \hi
    la t5, \next
    sfence.vma t5
    lw t4, -256(a2)
    .rept 1016
    nop
    .endr
    \instr
    nop
    nop
    .half 0x0913
.endm
.macro PAGE4 hi, next, instr:vararg
    .half \hi
    la t5, \next
    sfence.vma t5
    lw t4, -256(a2)
    .rept 1015
    nop
    .endr
    \instr
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913
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

    // Bring the data page into the DTLB, so the accesses below miss only in the cache, not the TLB.
    la a2, cold_lines
    lw a7, 0(a2)
    addi a2, a2, 256            # cold lines the warm-up load did not touch
    li s2, 0                    # counts the straddling addi s2, s2, 1 instructions
    j page1

.p2align 12
page1 = . + 2                   # entered by a jump, past the first halfword
    PAGE3 0x0001, page2, lw s3, 0(a2)
page2 = . + 2
    PAGE3 0x0019, page3, sw s3, 64(a2)
page3 = . + 2
    PAGE3 0x0019, page4, lw s4, 128(a2)
page4 = . + 2
    PAGE2 0x0019, page5, lw s5, 192(a2)
page5 = . + 2
    PAGE2 0x0019, page6, sw s4, 256(a2)
page6 = . + 2
    PAGE2 0x0019, page7, lw s6, 320(a2)
page7 = . + 2
    PAGE4 0x0019, page8, lw s7, 384(a2)
page8 = . + 2
    PAGE4 0x0019, page9, sw s5, 448(a2)
page9 = . + 2
    PAGE4 0x0019, page10, lw s8, 512(a2)
page10:
    .half 0x0019                # high half of the last straddling addi
    li a0, 3
    ecall

    // Every straddling addi ran exactly once
    li t2, 9
    SC_CHECK_EQ s2, t2, 1
    li t2, COLD + 0
    SC_CHECK_EQ a7, t2, 2       # warm-up load
    // Held loads: word k of cold_lines holds COLD + k, and a2 points at word 64
    li t2, COLD + 64
    SC_CHECK_EQ s3, t2, 3
    li t2, COLD + 96
    SC_CHECK_EQ s4, t2, 4
    li t2, COLD + 112
    SC_CHECK_EQ s5, t2, 5
    li t2, COLD + 144
    SC_CHECK_EQ s6, t2, 6
    li t2, COLD + 160
    SC_CHECK_EQ s7, t2, 7
    li t2, COLD + 192
    SC_CHECK_EQ s8, t2, 8
    // Held stores, one word each; the word after the first is untouched
    lw t3, 64(a2)
    li t2, COLD + 64
    SC_CHECK_EQ t3, t2, 9
    lw t3, 68(a2)
    li t2, COLD + 81
    SC_CHECK_EQ t3, t2, 10
    lw t3, 256(a2)
    li t2, COLD + 96
    SC_CHECK_EQ t3, t2, 11
    lw t3, 448(a2)
    li t2, COLD + 112
    SC_CHECK_EQ t3, t2, 12

    SC_PASS
    j done

.data
.p2align 12
roottable:
    .fill 1024, 4, 0
l0table:
    .fill 1024, 4, 0
cold_lines:
    .set k, 0
    .rept 1024
    .word COLD + k
    .set k, k + 1
    .endr
