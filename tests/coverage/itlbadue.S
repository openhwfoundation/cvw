///////////////////////////////////////////
// itlbadue.S
//
// Written: David_Harris@hmc.edu 9 October 2026
//
// Purpose: ITLB hit on an entry with A=0 while Svadu hardware updating is enabled (menvcfg.ADUE=1).
//          With ADUE=0, a fetch from a page whose leaf PTE has A=0 walks the page table, fills the ITLB
//          with the A=0 leaf, and then raises an instruction page fault from the ITLB hit.  Setting ADUE=1
//          without sfence.vma and fetching from the page again hits that cached A=0 entry, so the ITLB
//          requests an A update (ifu.sv: InstrUpdateAF = 1 in ITLBMissOrUpdateRawF), the walker sets A
//          in the PTE, and the fetch proceeds.  Self-checking (WALLY-selfcheck.h).
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

#define CODE_VA  0xC0000000             // virtual address of the code page
#define PTE_PTR  0x01                   // V: pointer to the next level
#define PTE_RX   0x0B                   // V R X, A = D = 0: executable leaf that has never been accessed
#define PTE_A    0x40
#define RETVAL   0x5A                   // returned in a5 by the code page

// PTE t0 = ((page address in \adr >> 12) << 10) | \flags
.macro MAKEPTE adr, flags
    srli t0, \adr, 12
    slli t0, t0, 10
    ori  t0, t0, \flags
.endm

main:
    // Sv39 page table: VA 0x80000000-0xBFFFFFFF identity gigapage (V R W X A D);
    // VA 0xC0000000 kilopage -> code_page with A = 0
    la a1, pagetable_root
    la a2, pagetable_l1
    la a3, pagetable_l0
    li t0, 0x200000CF
    sd t0, 16(a1)                       // root[2]: identity gigapage
    MAKEPTE a2, PTE_PTR
    sd t0, 24(a1)                       // root[3] -> level 1 table
    MAKEPTE a3, PTE_PTR
    sd t0, 0(a2)                        // level1[0] -> level 0 table
    la t1, code_page
    MAKEPTE t1, PTE_RX
    sd t0, 0(a3)                        // level0[0]: code page leaf, A = 0
    mv s2, t0                           // s2 = original leaf PTE

    li t0, 1
    slli t0, t0, 61
    csrc menvcfg, t0                    // menvcfg.ADUE = 0: A updates are left to software
    la t0, ifault
    csrw mtvec, t0
    la t0, pagetable_root               // satp = Sv39, root page table
    srli t0, t0, 12
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
    li s0, CODE_VA

    // 1. ADUE = 0: the fetch walks, fills the ITLB with the A = 0 leaf, and page faults; A stays 0
    li s10, 0
    li s11, 0
    li a5, 0
    li a0, 1
    ecall                               // to S mode
    jalr ra, 0(s0)                      // instruction page fault; ifault resumes at ra
    li a0, 3
    ecall                               // back to M mode
    li t2, 12
    SC_CHECK_EQ s10, t2, 1              // mcause = instruction page fault
    SC_CHECK_EQ s11, s0, 2              // mtval = CODE_VA
    SC_CHECK_EQ a5, zero, 3             // the code page did not run
    ld t2, 0(a3)
    SC_CHECK_EQ t2, s2, 4               // A still 0

    // 2. ADUE = 1 with no sfence.vma: the fetch hits the cached A = 0 entry, so the walker sets A
    //    (InstrUpdateAF) and the code page runs
    li t0, 1
    slli t0, t0, 61
    csrs menvcfg, t0                    // menvcfg.ADUE = 1
    li s10, 0
    li a0, 1
    ecall                               // to S mode
    jalr ra, 0(s0)                      // code page sets a5 = RETVAL
    li a0, 3
    ecall                               // back to M mode
    SC_CHECK_EQ s10, zero, 5            // no page fault
    li t2, RETVAL
    SC_CHECK_EQ a5, t2, 6               // the code page ran
    ld t2, 0(a3)
    ori s2, s2, PTE_A
    SC_CHECK_EQ t2, s2, 7               // A = 1 (D still 0)

    SC_PASS
    j done

// Instruction page faults: record mcause in s10 and mtval in s11 and resume after the jalr (at ra) in S mode.
// Everything else goes to sc_trap_handler, which passes ecalls to the WALLY-init-lib.h handler and fails the
// test on any other trap.
.align 4
ifault:
    csrr s9, mcause
    addi s9, s9, -12
    bnez s9, sc_trap_handler
    li s10, 12
    csrr s11, mtval
    csrw mepc, ra
    mret

.data
.align 12
pagetable_root:
    .fill 512, 8, 0
.align 12
pagetable_l1:
    .fill 512, 8, 0
.align 12
pagetable_l0:
    .fill 512, 8, 0
.align 12
code_page:
    li a5, RETVAL
    ret
