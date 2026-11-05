///////////////////////////////////////////
// hptwamoioptes.S
//
// Written: david_harris@hmc.edu 1 November 2026
//
// Purpose: Check that a page table walk caused by an AMO's DTLB miss reads uncacheable PTEs without
//          writing them.  The walker clears the atomic control for its own PTE reads, but the LSU once
//          used the AMO's control to choose an atomic bus transaction for uncacheable accesses, so each
//          bus PTE read became a read-modify-write that overwrote the PTE with the walker's previous
//          PTE.  The level-0 page table here is the CLINT page holding mtimecmp, so its entry 0 is
//          mtimecmp and the walk reaches it over the bus.  The test runs AMOs that miss in the DTLB
//          and checks that every PTE survives.  It is self-checking (WALLY-selfcheck.h): it reports
//          the outcome through tohost.
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

// Page table entry flag combinations
#define PTE_PTR  0x01                   // V, pointer to the next level
#define PTE_RWL  0xC7                   // V R W A D: read/write leaf with A and D already set

#define MTIMECMP 0x02004000             // CLINT mtimecmp for hart 0, at the start of a page

// PTE t0 = ((page address in \adr >> 12) << 10) | \flags
.macro MAKEPTE adr, flags
    srli t0, \adr, 12
    slli t0, t0, 10
    ori  t0, t0, \flags
.endm

// CHECKPTE table, offset, expected, index: fail unless the PTE at table + offset still holds expected
.macro CHECKPTE table, offset, expected, index
    ld s3, \offset(\table)
    SC_CHECK_EQ s3, \expected, \index
.endm

main:
    SC_STRICT_TRAPS                     // a page fault from a corrupted page table fails the test

    ////////////////////////////////////////////////////////////////////////////////////////////
    // Build an Sv39 page table in machine mode
    //   VA 0x00000000-0x3FFFFFFF: identity gigapage (CLINT), so the test can read mtimecmp
    //   VA 0x80000000-0xBFFFFFFF: identity gigapage (code, data, stack, page tables)
    //   VA 0xC0000000:            kilopage mapping data_page through l1 and the level-0 table in the CLINT
    // mie = 0, so mtimecmp holding a PTE raises no interrupt.
    ////////////////////////////////////////////////////////////////////////////////////////////
    la a1, pagetable_l2
    la a2, pagetable_l1
    li a3, MTIMECMP

    li t0, 0x000000C7                   // identity gigapage at 0, V R W A D
    sd t0, 0(a1)                        // l2[0]
    li t0, 0x200000CF                   // identity gigapage at 0x80000000, V R W X A D
    sd t0, 16(a1)                       // l2[2]
    MAKEPTE a2, PTE_PTR
    mv s5, t0
    sd s5, 24(a1)                       // l2[3] -> level 1 table (VA 0xC0000000)
    MAKEPTE a3, PTE_PTR
    mv s6, t0
    sd s6, 0(a2)                        // l1[0] -> level 0 table in the CLINT
    la t1, data_page
    MAKEPTE t1, PTE_RWL
    mv s7, t0
    sd s7, 0(a3)                        // l0[0] = mtimecmp -> data_page

    li t0, 100
    sd t0, 0(t1)                        // data_page[0] = 100
    li t0, 0x11
    sw t0, 8(t1)                        // data_page[8] = 0x11

    la t0, pagetable_l2                 // satp = Sv39, ASID 0, root page table
    srli t0, t0, 12
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                               // enter supervisor mode

    li s0, 0xC0000000                   // virtual address of data_page

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 1. amoadd.d misses in the DTLB and walks all three levels; the last read is from the CLINT
    ////////////////////////////////////////////////////////////////////////////////////////////
    li t2, 5
    amoadd.d s3, t2, (s0)
    li t2, 100
    SC_CHECK_EQ s3, t2, 1
    CHECKPTE a1, 24, s5, 2
    CHECKPTE a2, 0,  s6, 3
    CHECKPTE a3, 0,  s7, 4

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 2. After sfence.vma, amoswap.w walks again through the same PTEs
    ////////////////////////////////////////////////////////////////////////////////////////////
    sfence.vma
    addi s1, s0, 8
    li t2, 0x22
    amoswap.w s3, t2, (s1)
    li t2, 0x11
    SC_CHECK_EQ s3, t2, 5
    CHECKPTE a1, 24, s5, 6
    CHECKPTE a2, 0,  s6, 7
    CHECKPTE a3, 0,  s7, 8

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 3. A load that walks again sees both AMO results through the intact page table
    ////////////////////////////////////////////////////////////////////////////////////////////
    sfence.vma
    ld s3, 0(s0)
    li t2, 105
    SC_CHECK_EQ s3, t2, 9
    lw s3, 8(s0)
    li t2, 0x22
    SC_CHECK_EQ s3, t2, 10

    ////////////////////////////////////////////////////////////////////////////////////////////
    // Every check passed
    ////////////////////////////////////////////////////////////////////////////////////////////
    li a0, 3
    ecall                               // return to machine mode to terminate
    li t0, -1
    li t1, MTIMECMP
    sd t0, 0(t1)                        // restore mtimecmp to its reset value
    SC_PASS
    j done

.data
.align 12
pagetable_l2:
    .fill 512, 8, 0
.align 12
pagetable_l1:
    .fill 512, 8, 0
.align 12
data_page:
    .fill 512, 8, 0
