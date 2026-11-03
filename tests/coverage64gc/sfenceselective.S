///////////////////////////////////////////
// sfenceselective.S
//
// Written: david_harris@hmc.edu 16 October 2026
//
// Purpose: Check that sfence.vma and sinval.vma invalidate the TLB entries they name and leave the others
//          (TLB_EXACT_FENCE_INVAL = 1).
//          An address-scoped fence (rs1 != x0) must invalidate every entry whose page holds the address,
//          including a megapage entry addressed through a different 4 KiB page; an ASID-scoped fence
//          (rs2 != x0) must invalidate the non-global entries of that ASID.  Wally keeps the other
//          entries, which the test observes by remapping a page without a covering fence: the stale
//          entry still translates to the old page, which the privileged specification permits.
//          sfence.w.inval and sfence.inval.ir must not flush the entries sinval.vma kept, and sfence.inval.ir
//          must make later instruction fetches use the new translation.
//          Self-checking (WALLY-selfcheck.h).
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

#define PTE_PTR  0x01                   // V, pointer to the next level
#define PTE_RWL  0xC7                   // V R W A D:   non-global read/write leaf
#define PTE_RXL  0xCB                   // V R X A D:   non-global read/execute leaf

#define DATA_A 0x0A0A0A0A
#define DATA_B 0x0B0B0B0B

// Physical megapages beyond the program image, written in machine mode before translation is on
#define MEGA_A 0x80400000
#define MEGA_B 0x80600000
#define MEGA_OFF 0x5000                 // offset of the word read through the megapage
#define INVAL_OFF 0x100                 // offset of the Svinval sequence in the code pages

// PTE t0 = ((page address in \adr >> 12) << 10) | \flags
.macro MAKEPTE adr, flags
    srli t0, \adr, 12
    slli t0, t0, 10
    ori  t0, t0, \flags
.endm

// satp = Sv48 with ASID \asid and the root page table
.macro SETSATP asid
    la t0, pagetable_root
    srli t0, t0, 12
    li t1, \asid
    slli t1, t1, 44
    or t0, t0, t1
    li t1, 9
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0
.endm

main:
    ////////////////////////////////////////////////////////////////////////////////////////////
    // Sv48 page table, built in machine mode:
    //   VA 0x80000000-0xBFFFFFFF: identity gigapage (code, data, stack)
    //   VA 0xC0000000 (X), 0xC0001000 (Y): data kilopages, each mapped to data page A or B
    //   VA 0xC0002000 (C): code kilopage, mapped to code page A or B
    //   VA 0xC0200000 (M): megapage, mapped to MEGA_A or MEGA_B
    ////////////////////////////////////////////////////////////////////////////////////////////
    la a1, pagetable_root
    la a2, pagetable_l2
    la a3, pagetable_l1
    la a4, pagetable_l0

    MAKEPTE a2, PTE_PTR
    sd t0, 0(a1)                        // root[0] -> level 2 table
    li t0, 0x200000CF
    sd t0, 16(a2)                       // level2[2] = identity gigapage at 0x80000000, V R W X A D
    MAKEPTE a3, PTE_PTR
    sd t0, 24(a2)                       // level2[3] -> level 1 table (VA 0xC0000000)
    MAKEPTE a4, PTE_PTR
    sd t0, 0(a3)                        // level1[0] -> level 0 table
    li t1, MEGA_A
    MAKEPTE t1, PTE_RWL
    sd t0, 8(a3)                        // level1[1]: megapage M -> MEGA_A

    la t1, data_page_a
    MAKEPTE t1, PTE_RWL
    sd t0, 0(a4)                        // level0[0]: X -> data page A
    sd t0, 8(a4)                        // level0[1]: Y -> data page A
    la t1, code_page_a
    MAKEPTE t1, PTE_RXL
    sd t0, 16(a4)                       // level0[2]: C -> code page A

    li t0, DATA_A
    la t1, data_page_a
    sd t0, 0(t1)
    li t1, MEGA_A + MEGA_OFF
    sd t0, 0(t1)
    li t0, DATA_B
    la t1, data_page_b
    sd t0, 0(t1)
    li t1, MEGA_B + MEGA_OFF
    sd t0, 0(t1)

    SETSATP 1
    sfence.vma

    li a0, 1
    ecall                               // enter supervisor mode

    li s0, 0xC0000000                   // X
    li s1, 0xC0001000                   // Y
    li s2, 0xC0002000                   // C
    li s3, 0xC0200000 + MEGA_OFF        // the word read through megapage M
    la s4, pagetable_l0
    la s5, pagetable_l1
    li s6, DATA_A
    li s7, DATA_B
    li s8, 1                            // ASID 1
    li s9, 2                            // ASID 2

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 1. Address-scoped fence: X and Y are in the TLB; remap both to page B and fence only X
    ////////////////////////////////////////////////////////////////////////////////////////////
    ld t2, 0(s0)
    SC_CHECK_EQ t2, s6, 1
    ld t2, 0(s1)
    SC_CHECK_EQ t2, s6, 2
    la t1, data_page_b
    MAKEPTE t1, PTE_RWL
    sd t0, 0(s4)
    sd t0, 8(s4)
    sfence.vma s0, s8                   // X in ASID 1
    ld t2, 0(s0)
    SC_CHECK_EQ t2, s7, 3               // X was invalidated
    ld t2, 0(s1)
    SC_CHECK_EQ t2, s6, 4               // Y kept its entry
    sfence.vma s1, x0                   // Y in every address space
    ld t2, 0(s1)
    SC_CHECK_EQ t2, s7, 5

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 2. A megapage entry is invalidated by a fence on another 4 KiB page within it, and kept by a
    //    fence on a page outside it
    ////////////////////////////////////////////////////////////////////////////////////////////
    ld t2, 0(s3)
    SC_CHECK_EQ t2, s6, 6
    li t1, MEGA_B
    MAKEPTE t1, PTE_RWL
    sd t0, 8(s5)
    sfence.vma s1, x0                   // Y, outside the megapage
    ld t2, 0(s3)
    SC_CHECK_EQ t2, s6, 7               // the megapage kept its entry
    li t1, 0xC0209000                   // another 4 KiB page of the megapage
    sfence.vma t1, x0
    ld t2, 0(s3)
    SC_CHECK_EQ t2, s7, 8

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 3. ASID-scoped fence: an entry installed under ASID 2 survives a fence of ASID 1 and is
    //    invalidated by a fence of ASID 2
    ////////////////////////////////////////////////////////////////////////////////////////////
    la t1, data_page_a
    MAKEPTE t1, PTE_RWL
    sd t0, 0(s4)                        // X -> page A
    li a0, 3
    ecall                               // machine mode to write satp
    SETSATP 2
    sfence.vma
    li a0, 1
    ecall                               // back to supervisor mode
    ld t2, 0(s0)                        // installs X under ASID 2
    SC_CHECK_EQ t2, s6, 9
    la t1, data_page_b
    MAKEPTE t1, PTE_RWL
    sd t0, 0(s4)                        // X -> page B
    sfence.vma x0, s8                   // ASID 1
    ld t2, 0(s0)
    SC_CHECK_EQ t2, s6, 10              // the ASID 2 entry was kept
    sfence.vma s0, s8                   // X in ASID 1
    ld t2, 0(s0)
    SC_CHECK_EQ t2, s6, 11              // still kept
    sfence.vma x0, s9                   // ASID 2
    ld t2, 0(s0)
    SC_CHECK_EQ t2, s7, 12

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 4. Instruction TLB: C runs code page A under ASID 2; remap it to code page B.  A fence of
    //    ASID 1 keeps the entry; a fence of C in ASID 2 invalidates it.
    ////////////////////////////////////////////////////////////////////////////////////////////
    li s10, 0xA
    li s11, 0xB
    jalr ra, 0(s2)
    SC_CHECK_EQ a5, s10, 13
    la t1, code_page_b
    MAKEPTE t1, PTE_RXL
    sd t0, 16(s4)
    sfence.vma x0, s8                   // ASID 1
    jalr ra, 0(s2)
    SC_CHECK_EQ a5, s10, 14             // the ASID 2 entry was kept
    sfence.vma s2, s9                   // C in ASID 2
    jalr ra, 0(s2)
    SC_CHECK_EQ a5, s11, 15

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 5. Svinval: sinval.vma invalidates the entries it names, as sfence.vma does, and the
    //    sfence.w.inval / sfence.inval.ir around it keep the others
    ////////////////////////////////////////////////////////////////////////////////////////////
    la t1, data_page_a
    MAKEPTE t1, PTE_RWL
    sd t0, 0(s4)                        // X -> page A
    sd t0, 8(s4)                        // Y -> page A
    sfence.vma
    ld t2, 0(s0)
    SC_CHECK_EQ t2, s6, 16
    ld t2, 0(s1)
    SC_CHECK_EQ t2, s6, 17
    la t1, data_page_b
    MAKEPTE t1, PTE_RWL
    sd t0, 0(s4)                        // X -> page B
    sd t0, 8(s4)                        // Y -> page B
    sfence.w.inval
    sinval.vma s0, x0                   // X in every address space
    sfence.inval.ir
    ld t2, 0(s0)
    SC_CHECK_EQ t2, s7, 18              // X was invalidated
    ld t2, 0(s1)
    SC_CHECK_EQ t2, s6, 19              // Y kept its entry
    sfence.w.inval
    sinval.vma x0, s8                   // ASID 1
    sfence.inval.ir
    ld t2, 0(s1)
    SC_CHECK_EQ t2, s6, 20              // the ASID 2 entry for Y was kept
    sfence.w.inval
    sinval.vma x0, s9                   // ASID 2
    sfence.inval.ir
    ld t2, 0(s1)
    SC_CHECK_EQ t2, s7, 21

    // C runs code page A; remap it to code page B and jump to the invalidation sequence at
    // C + INVAL_OFF.  It is fetched from page A through the stale entry and invalidates C, so the
    // instructions after sfence.inval.ir must come from page B.
    la t1, code_page_a
    MAKEPTE t1, PTE_RXL
    sd t0, 16(s4)                       // C -> code page A
    sfence.vma
    jalr ra, 0(s2)
    SC_CHECK_EQ a5, s10, 22
    la t1, code_page_b
    MAKEPTE t1, PTE_RXL
    sd t0, 16(s4)                       // C -> code page B
    addi t1, s2, INVAL_OFF
    jalr ra, 0(t1)
    SC_CHECK_EQ a5, s11, 23

    li a0, 3
    ecall                               // return to machine mode to terminate
    SC_PASS
    j done

.data
.align 12
pagetable_root:
    .fill 512, 8, 0
.align 12
pagetable_l2:
    .fill 512, 8, 0
.align 12
pagetable_l1:
    .fill 512, 8, 0
.align 12
pagetable_l0:
    .fill 512, 8, 0

.align 12
data_page_a:
    .dword 0
.align 12
data_page_b:
    .dword 0
.align 12
code_page_a:
    li a5, 0xA
    ret
.org code_page_a + INVAL_OFF
    sfence.w.inval
    sinval.vma s2, s9                   // C in ASID 2
    sfence.inval.ir
    li a5, 0xA
    ret
.align 12
code_page_b:
    li a5, 0xB
    ret
.org code_page_b + INVAL_OFF
    sfence.w.inval
    sinval.vma s2, s9
    sfence.inval.ir
    li a5, 0xB
    ret
