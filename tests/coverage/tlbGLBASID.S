///////////////////////////////////////////
// tlbGLBASID.S
//
// Written: david_harris@hmc.edu 29 May 2026
//
// Purpose: Coverage for the tlbcamline ShouldFlush expression (issue #1538 global preservation):
//              assign ShouldFlush = TLBFlush & (~PTE_G | TLBFlushAll);
//          Fills every TLB entry (ITLB and DTLB) with global (PTE_G=1) mappings, then issues both
//          an ASID-scoped sfence.vma (rs2 != x0 => TLBFlushAll=0) and a full sfence.vma
//          (rs2 == x0 => TLBFlushAll=1) while those global entries are resident.  This exercises the
//          three focused-expression rows that no existing test reached for most camlines:
//              PTE_G_1       (non-masking TLBFlush && ~TLBFlushAll)
//              TLBFlushAll_0 (non-masking TLBFlush && PTE_G)
//              TLBFlushAll_1 (non-masking TLBFlush && PTE_G)
//          tlbGLB.S installs global entries but never issues sfence.vma; tlbASID.S issues sfence.vma
//          but with no global entry resident.  Page table reused from tlbGLB.S.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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


// load code to initialize stack, handle interrupts, terminate

#include "WALLY-init-lib.h"

# run-elf.bash find this in project description
main:
    # Page table root address at 0x80080000, ASID = 0 (SV48)
    li t5, 0x9000000000080080
    csrw satp, t5

    # switch to supervisor mode
    li a0, 1
    ecall

    li t3, 48                       # distinct pages per fill (> TLB entries so replacement churns every line)
    li t4, 0x1000                   # offset between pages
    li t1, 0x00008067               # "ret" (jalr x0, x1, 0) instruction word

    # Each round fills every ITLB and DTLB entry with global (G=1) pages (store a ret into each page
    # => DTLB fill; fetch/execute it => ITLB fill) and then issues an sfence.vma while those global
    # entries are resident.  We alternate full and ASID-scoped fences across four rounds so that,
    # regardless of replacement order, every camline holds a global entry during both a
    # TLBFlushAll=1 fence (covers the TLBFlushAll_1 row) and a TLBFlushAll=0 fence (covers the
    # PTE_G_1 and TLBFlushAll_0 rows) of:  assign ShouldFlush = TLBFlush & (~PTE_G | TLBFlushAll);

    # ---- round 1: fill, then FULL sfence.vma (rs2 = x0 => TLBFlushAll = 1) ----
    li t0, 0xC0000000
    li t2, 0
fillA:
    bge t2, t3, flushA
    sw t1, 0(t0)
    fence.i
    jalr t0
    add t0, t0, t4
    addi t2, t2, 1
    j fillA
flushA:
    sfence.vma

    # ---- round 2: fill, then ASID-scoped sfence.vma (rs2 = t2 != x0 => TLBFlushAll = 0) ----
    li t0, 0xC0000000
    li t2, 0
fillB:
    bge t2, t3, flushB
    sw t1, 0(t0)
    fence.i
    jalr t0
    add t0, t0, t4
    addi t2, t2, 1
    j fillB
flushB:
    li t2, 1
    sfence.vma x0, t2

    # ---- round 3: fill, then FULL sfence.vma ----
    li t0, 0xC0000000
    li t2, 0
fillC:
    bge t2, t3, flushC
    sw t1, 0(t0)
    fence.i
    jalr t0
    add t0, t0, t4
    addi t2, t2, 1
    j fillC
flushC:
    sfence.vma

    # ---- round 4: fill, then ASID-scoped sfence.vma ----
    li t0, 0xC0000000
    li t2, 0
fillD:
    bge t2, t3, flushD
    sw t1, 0(t0)
    fence.i
    jalr t0
    add t0, t0, t4
    addi t2, t2, 1
    j fillD
flushD:
    li t2, 1
    sfence.vma x0, t2

    j done

.data
.align 19
# level 3 Page table situated at 0x80080000, points to 0x80081000
pagetable:
    .8byte 0x20020401

.align 12 // level 2 page table, contains direction to a gigapage
    .8byte 0x0
    .8byte 0x0
    .8byte 0x200000EF // gigapage that starts at 8000 0000 goes to C000 0000
    .8byte 0x20020821 // pointer to next page table entry at 8008 2000

.align 12 // level 1 page table, points to level 0 page table
    .8byte 0x20020C21

.align 12 // level 0 page table, contains 64 global kilopages
    .8byte 0x200000EF // access xC000 0000
    .8byte 0x200004EF // access xC000 1000
    .8byte 0x200008EF // access xC000 2000
    .8byte 0x20000CEF // access xC000 3000

    .8byte 0x200010EF // access xC000 4000
    .8byte 0x200014EF
    .8byte 0x200018EF
    .8byte 0x20001CEF

    .8byte 0x200020EF // access xC000 8000
    .8byte 0x200024EF
    .8byte 0x200028EF
    .8byte 0x20002CEF

    .8byte 0x200030EF // access xC000 C000
    .8byte 0x200034EF
    .8byte 0x200038EF
    .8byte 0x20003CEF

    .8byte 0x200040EF // access xC001 0000
    .8byte 0x200044EF
    .8byte 0x200048EF
    .8byte 0x20004CEF

    .8byte 0x200050EF // access xC001 4000
    .8byte 0x200054EF
    .8byte 0x200058EF
    .8byte 0x20005CEF

    .8byte 0x200060EF // access xC001 8000
    .8byte 0x200064EF
    .8byte 0x200068EF
    .8byte 0x20006CEF

    .8byte 0x200070EF // access xC001 C000
    .8byte 0x200074eF
    .8byte 0x200078EF
    .8byte 0x20007CEF

    .8byte 0x200080EF // access xC002 0000
    .8byte 0x200084EF
    .8byte 0x200088EF
    .8byte 0x20008CEF

    .8byte 0x200010EF // access xC000 4000
    .8byte 0x200014EF
    .8byte 0x200018EF
    .8byte 0x20001CEF

    .8byte 0x200020EF // access xC000 8000
    .8byte 0x200024EF
    .8byte 0x200028EF
    .8byte 0x20002CEF

    .8byte 0x200030EF // access xC000 C000
    .8byte 0x200034EF
    .8byte 0x200038EF
    .8byte 0x20003CEF

    .8byte 0x200040EF // access xC001 0000
    .8byte 0x200044EF
    .8byte 0x200048EF
    .8byte 0x20004CEF

    .8byte 0x200050EF // access xC001 4000
    .8byte 0x200054EF
    .8byte 0x200058EF
    .8byte 0x20005CEF

    .8byte 0x200060EF // access xC001 8000
    .8byte 0x200064EF
    .8byte 0x200068EF
    .8byte 0x20006CEF

    .8byte 0x200070EF // access xC001 C000
    .8byte 0x200074eF
    .8byte 0x200078EF
    .8byte 0x20007CEF

    .8byte 0x200080EF // access xC002 0000
    .8byte 0x200084EF
    .8byte 0x200088EF
    .8byte 0x20008CEF
