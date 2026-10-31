///////////////////////////////////////////
// hptwl0miss.S
//
// Written: David_Harris@hmc.edu 30 October 2026
//
// Purpose: rv32gc: a page table walk whose level-0 PTE read misses the D$, so the walker waits in L0_RD
//          while DCacheBusStallM is set (hptw.sv: L0_RD -> L0_RD).  Sv32 maps DATA_VA through a level-0
//          table; M mode writes the table and flushes its line from the D$ with cbo.flush, then S mode
//          loads from DATA_VA.  The DTLB misses, the walk reads the root PTE and then the flushed level-0
//          PTE, which must be fetched from memory.
//          Self-checking: the load returns the word at the start of the data page (failure index 1), and
//          no trap but the privilege-change ecalls occurs.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define DATA_VA  0xC0000000             // virtual address of the data page (root index 0x300)
#define PTE_PTR  0x01                   // V: pointer to the next level
#define PTE_RWXAD 0xCF                  // V R W X A D leaf
#define PATTERN  0x13579BDF

main:
    SC_STRICT_TRAPS                     // fail on any trap but an ecall

    // Sv32 page table: VA 0x80000000-0x803FFFFF identity megapage (V R W X A D);
    // VA DATA_VA -> data_page through the level-0 table
    la a1, pagetable_root
    la a3, pagetable_l0
    li t0, 0x200000CF
    li t1, 0x200*4
    add t1, t1, a1
    sw t0, 0(t1)                        // root[0x200]: identity megapage
    srli t0, a3, 12
    slli t0, t0, 10
    ori t0, t0, PTE_PTR
    li t1, 0x300*4
    add t1, t1, a1
    sw t0, 0(t1)                        // root[0x300] -> level 0 table
    la t1, data_page
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, PTE_RWXAD
    sw t1, 0(a3)                        // level0[0]: data page
    cbo.flush (a3)                      // write the level-0 line back and drop it from the D$

    la t0, pagetable_root               // satp = Sv32, root page table
    srli t0, t0, 12
    li t1, 1
    slli t1, t1, 31
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                               // to S mode
    li t0, DATA_VA
    lw t2, 0(t0)                        // DTLB miss: the walk's level-0 read misses the D$
    li t3, PATTERN
    SC_CHECK_EQ t2, t3, 1

    li a0, 3
    ecall                               // back to M mode
    csrw satp, zero
    SC_PASS
    j done

.data
.align 12
pagetable_root:
    .fill 1024, 4, 0
.align 12
pagetable_l0:
    .fill 1024, 4, 0
.align 12
data_page:
    .word PATTERN
    .fill 1023, 4, 0
