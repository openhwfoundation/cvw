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
//          Self-checking (WALLY-selfcheck.h).  Each fill stores "addi a5, x0, ID; ret" into its
//          page, where ID = (round << 6) | the physical page the VA maps, and checks that the fetch
//          right after runs that code.  The global PTEs are repointed from physical pages set A
//          (0x80000000 + p * 0x1000) to set B (0x80040000 + p * 0x1000) before the first full
//          sfence.vma and back before the second, so a global ITLB entry that survives a full fence
//          fetches the other set's code and a global DTLB entry that survives stores into the other
//          set, leaving the fetched page without this round's code.  The ASID-scoped fences may keep
//          the global entries, so the mapping does not change across them.  At the end, machine mode
//          checks that set A holds round 4's code and set B round 3's.  Failure indices: 1-4 fill
//          fetch in rounds 1-4, 5 set A contents, 6 set B contents, 0xF0 any trap but an ecall.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

// The page tables come before WALLY-selfcheck.h so that its data does not move them off the
// addresses that satp and the pointer PTEs name (0x80080000-0x80083FFF).
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
pt_l0:
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

#include "WALLY-selfcheck.h"

// VA page i (VA 0xC0000000 + i * 0x1000) maps physical page p of the current set, with p = i for
// i < 36 and p = i - 32 for the entries 36-67 that repeat pages 4-35.
#define NPAGES  36
#define SETA    0x80000                 // first PPN of physical page set A (the PTEs above)
#define SETB    0x80040                 // first PPN of physical page set B
#define RETADDI 0x0000806700000793      // "ret" << 32 | "addi a5, x0, 0": the code stored in each page

// PAGEOF p, i: p = the physical page number that VA page i maps
.macro PAGEOF p, i
    sltiu \p, \i, NPAGES
    xori  \p, \p, 1
    slli  \p, \p, 5
    sub   \p, \i, \p
.endm

// CODEWORD dst, id: dst = "addi a5, x0, id; ret" with id in a register (s11 = RETADDI)
.macro CODEWORD dst, id
    slli \dst, \id, 20
    or   \dst, \dst, s11
.endm

// FILLCHECK index: the fill loop body for the page at VA t0 (VA page t2): store the code with ID
// s10 | p into it, fetch and run it, and check that it ran
.macro FILLCHECK index
    PAGEOF a3, t2
    or a3, a3, s10                  # a3 = ID of the code this page must run
    CODEWORD t1, a3
    sd t1, 0(t0)                    # store the code into the page (DTLB fill)
    fence.i
    li a5, -1
    jalr t0                         # fetch and run it (ITLB fill)
    SC_CHECK_EQ_ADR a5, a3, t0, \index
.endm

// REMAP set: point the global PTEs of VA pages 0-47 at the physical pages of a set (first PPN set)
.macro REMAP set
    la a1, pt_l0
    li a2, 0
1:  PAGEOF a3, a2
    li a4, \set
    add a3, a3, a4
    slli a3, a3, 10
    ori a3, a3, 0xEF                # V R W X G A D
    sd a3, 0(a1)
    addi a1, a1, 8
    addi a2, a2, 1
    blt a2, t3, 1b
.endm

// SWEEP set, round, index: check that each physical page of a set holds the code of a round
.macro SWEEP set, round, index
    li t0, \set << 12
    li t2, 0
    li s10, \round << 6
1:  or a3, t2, s10
    CODEWORD a4, a3
    ld a5, 0(t0)
    SC_CHECK_EQ_ADR a5, a4, t0, \index
    add t0, t0, t4
    addi t2, t2, 1
    li a6, NPAGES
    blt t2, a6, 1b
.endm

# run-elf.bash find this in project description
main:
    SC_STRICT_TRAPS                 # fail on any trap but an ecall
    li s11, RETADDI

    # Page table root address at 0x80080000, ASID = 0 (SV48)
    li t5, 0x9000000000080080
    csrw satp, t5

    # switch to supervisor mode
    li a0, 1
    ecall

    li t3, 48                       # distinct pages per fill (> TLB entries so replacement churns every line)
    li t4, 0x1000                   # offset between pages

    # Each round fills every ITLB and DTLB entry with global (G=1) pages (store code into each page
    # => DTLB fill; fetch/execute it => ITLB fill) and then issues an sfence.vma while those global
    # entries are resident.  We alternate full and ASID-scoped fences across four rounds so that,
    # regardless of replacement order, every camline holds a global entry during both a
    # TLBFlushAll=1 fence (covers the TLBFlushAll_1 row) and a TLBFlushAll=0 fence (covers the
    # PTE_G_1 and TLBFlushAll_0 rows) of:  assign ShouldFlush = TLBFlush & (~PTE_G | TLBFlushAll);

    # ---- round 1: fill (set A), then FULL sfence.vma (rs2 = x0 => TLBFlushAll = 1) ----
    li s10, 1 << 6
    li t0, 0xC0000000
    li t2, 0
fillA:
    bge t2, t3, flushA
    FILLCHECK 1
    add t0, t0, t4
    addi t2, t2, 1
    j fillA
flushA:
    REMAP SETB                      # the full fence must drop the set A global entries
    sfence.vma

    # ---- round 2: fill (set B), then ASID-scoped sfence.vma (rs2 = t2 != x0 => TLBFlushAll = 0) ----
    li s10, 2 << 6
    li t0, 0xC0000000
    li t2, 0
fillB:
    bge t2, t3, flushB
    FILLCHECK 2
    add t0, t0, t4
    addi t2, t2, 1
    j fillB
flushB:
    li t2, 1
    sfence.vma x0, t2

    # ---- round 3: fill (set B, which the ASID-scoped fence may have kept), then FULL sfence.vma ----
    li s10, 3 << 6
    li t0, 0xC0000000
    li t2, 0
fillC:
    bge t2, t3, flushC
    FILLCHECK 3
    add t0, t0, t4
    addi t2, t2, 1
    j fillC
flushC:
    REMAP SETA                      # the full fence must drop the set B global entries
    sfence.vma

    # ---- round 4: fill (set A), then ASID-scoped sfence.vma ----
    li s10, 4 << 6
    li t0, 0xC0000000
    li t2, 0
fillD:
    bge t2, t3, flushD
    FILLCHECK 4
    add t0, t0, t4
    addi t2, t2, 1
    j fillD
flushD:
    li t2, 1
    sfence.vma x0, t2

    # ---- the stores went to the physical pages their PTEs named: set A holds round 4's code, set B round 3's ----
    li a0, 3
    ecall                           # machine mode: read the physical pages directly
    SWEEP SETA, 4, 5
    SWEEP SETB, 3, 6

    SC_PASS
    j done
