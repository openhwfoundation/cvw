///////////////////////////////////////////
// sfencevmaglobal.S
//
// Written: david_harris@hmc.edu 15 September 2026
//
// Purpose: Check sfence.vma invalidation of global (G=1) translations.
//          The RISC-V privileged specification requires sfence.vma to invalidate global mappings when
//          rs2 = x0 (the fence applies to all address spaces) and permits an ASID-scoped fence
//          (rs2 != x0) to leave them in place.  This test verifies the required direction on both the
//          data TLB and the instruction TLB, and that an ASID-scoped fence still invalidates
//          non-global mappings.  It is self-checking: the outcome is left in selfcheck_record.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"

// Page table entry flag combinations
#define PTE_PTR  0x01                   // V, pointer to the next level
#define PTE_RWGL 0xE7                   // V R W A D G: global read/write leaf
#define PTE_RWL  0xC7                   // V R W A D:   non-global read/write leaf
#define PTE_RXGL 0xEB                   // V R X A D G: global read/execute leaf

// Values stored in the two data pages and returned by the two code pages
#define DATA_A 0x0A0A0A0A
#define DATA_B 0x0B0B0B0B

// PTE t0 = ((page address in \adr >> 12) << 10) | \flags
.macro MAKEPTE adr, flags
    srli t0, \adr, 12
    slli t0, t0, 10
    ori  t0, t0, \flags
.endm

// Fail the test, recording which check failed along with the expected and actual values
.macro CHECKEQ actual, expected, index
    beq \actual, \expected, 8f
    la t0, selfcheck_record
    li t1, 2
    sd t1, 0(t0)                        // status 2: value mismatch
    li t1, \index
    sd t1, 8(t0)                        // which check failed
    sd zero, 16(t0)
    sd \expected, 24(t0)
    sd \actual, 32(t0)
    li a0, 3
    ecall                               // back to machine mode to terminate
    j done
8:
.endm

main:
    ////////////////////////////////////////////////////////////////////////////////////////////
    // Build an Sv48 page table in machine mode
    //   VA 0x80000000-0xBFFFFFFF: identity gigapage (code, data, stack), non-global
    //   VA 0xC0000000:            kilopage aliasing one of the two data pages
    //   VA 0xC0001000:            kilopage aliasing one of the two code pages
    ////////////////////////////////////////////////////////////////////////////////////////////
    la a1, pagetable_root
    la a2, pagetable_l2
    la a3, pagetable_l1
    la a4, pagetable_l0

    MAKEPTE a2, PTE_PTR
    sd t0, 0(a1)                        // root[0] -> level 2 table (VA[47:39] = 0)
    li t0, 0x200000CF
    sd t0, 16(a2)                       // level2[2] = identity gigapage at 0x80000000, V R W X A D
    MAKEPTE a3, PTE_PTR
    sd t0, 24(a2)                       // level2[3] -> level 1 table (VA 0xC0000000)
    MAKEPTE a4, PTE_PTR
    sd t0, 0(a3)                        // level1[0] -> level 0 table

    la t1, data_page_a
    MAKEPTE t1, PTE_RWGL
    sd t0, 0(a4)                        // level0[0]: global data mapping -> page A
    la t1, code_page_a
    MAKEPTE t1, PTE_RXGL
    sd t0, 8(a4)                        // level0[1]: global code mapping -> page A

    li t0, DATA_A
    la t1, data_page_a
    sd t0, 0(t1)
    li t0, DATA_B
    la t1, data_page_b
    sd t0, 0(t1)

    la t0, pagetable_root               // satp = Sv48, ASID 1, root page table
    srli t0, t0, 12
    li t1, 1
    slli t1, t1, 44
    or t0, t0, t1
    li t1, 9
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                               // enter supervisor mode

    li s0, 0xC0000000                   // virtual address of the aliased data page
    li s1, 0xC0001000                   // virtual address of the aliased code page
    la s2, pagetable_l0                 // level0[0] is the data mapping, level0[1] the code mapping
    li s4, DATA_A
    li s5, DATA_B

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 1. The global mapping translates to page A
    ////////////////////////////////////////////////////////////////////////////////////////////
    ld s3, 0(s0)
    CHECKEQ s3, s4, 1

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 2. sfence.vma x0, x0 must invalidate the global mapping: repoint it at page B
    ////////////////////////////////////////////////////////////////////////////////////////////
    la t1, data_page_b
    MAKEPTE t1, PTE_RWGL
    sd t0, 0(s2)
    sfence.vma
    ld s3, 0(s0)
    CHECKEQ s3, s5, 2

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 3. sfence.vma rs1, x0 (address-scoped, all address spaces) must also invalidate it
    ////////////////////////////////////////////////////////////////////////////////////////////
    la t1, data_page_a
    MAKEPTE t1, PTE_RWGL
    sd t0, 0(s2)
    sfence.vma s0, x0
    ld s3, 0(s0)
    CHECKEQ s3, s4, 3

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 4. An ASID-scoped sfence.vma must still invalidate a NON-global mapping
    ////////////////////////////////////////////////////////////////////////////////////////////
    la t1, data_page_b
    MAKEPTE t1, PTE_RWL
    sd t0, 0(s2)
    sfence.vma
    ld s3, 0(s0)                        // fills the TLB with the non-global mapping
    CHECKEQ s3, s5, 4
    la t1, data_page_a
    MAKEPTE t1, PTE_RWL
    sd t0, 0(s2)
    li a1, 1                            // the ASID this mapping was installed under
    sfence.vma x0, a1
    ld s3, 0(s0)
    CHECKEQ s3, s4, 5

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 5. A global mapping still translates correctly across an ASID-scoped sfence.vma, whether the
    //    implementation preserves the entry or refills it
    ////////////////////////////////////////////////////////////////////////////////////////////
    la t1, data_page_a
    MAKEPTE t1, PTE_RWGL
    sd t0, 0(s2)
    sfence.vma
    ld s3, 0(s0)
    CHECKEQ s3, s4, 6
    sfence.vma x0, a1
    ld s3, 0(s0)
    CHECKEQ s3, s4, 7

    ////////////////////////////////////////////////////////////////////////////////////////////
    // 6. The same requirement on the instruction TLB: a global executable mapping must be
    //    invalidated by sfence.vma x0, x0 and by the address-scoped form
    ////////////////////////////////////////////////////////////////////////////////////////////
    li s6, 0xA
    li s7, 0xB
    jalr ra, 0(s1)                      // code page A sets a5 = 0xA
    CHECKEQ a5, s6, 8

    la t1, code_page_b
    MAKEPTE t1, PTE_RXGL
    sd t0, 8(s2)
    sfence.vma
    jalr ra, 0(s1)                      // code page B sets a5 = 0xB
    CHECKEQ a5, s7, 9

    la t1, code_page_a
    MAKEPTE t1, PTE_RXGL
    sd t0, 8(s2)
    sfence.vma s1, x0
    jalr ra, 0(s1)
    CHECKEQ a5, s6, 10

    ////////////////////////////////////////////////////////////////////////////////////////////
    // Every check passed
    ////////////////////////////////////////////////////////////////////////////////////////////
    li a0, 3
    ecall                               // return to machine mode to terminate
    la t0, selfcheck_record
    li t1, 1
    sd t1, 0(t0)
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

// Two data pages and two code pages, each in its own physical page so that the mapping of
// VA 0xC0000000 / 0xC0001000 selects between them
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
.align 12
code_page_b:
    li a5, 0xB
    ret

.align 12
    .dword 0                            // keep selfcheck_record from sharing an address with another label
.globl selfcheck_record
selfcheck_record:
    .fill 8, 8, 0
