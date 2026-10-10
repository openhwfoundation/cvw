///////////////////////////////////////////
// tlbGLBHIT.S
//
// Written: David_Harris@hmc.edu 30 May 2026
//
// Purpose: Close the last uncovered FEC row in IFU TLB camline slot 2:
//          tlbcamline.sv:67  assign MatchASID = (SATP_ASID == Key_ASID) | PTE_G;
//          Row 4: PTE_G_1 with non-masking condition ~(SATP_ASID == Key_ASID) -- i.e. a *global*
//          entry that produces a TLB *hit* purely because PTE_G=1 while the queried ASID differs
//          from the stored Key_ASID.
//
//          The existing tlbGLBASID.S fills global entries and then sfences them (covering the
//          ShouldFlush PTE_G rows), but never re-queries a resident global entry under a mismatched
//          ASID, so the line-67 PTE_G_1 hit row stays uncovered for some camlines (slot 2).
//          This test fills every ITLB line with global (G=1) pages under one ASID, switches ASID
//          WITHOUT an sfence (global entries survive), then re-fetches the same pages so each
//          resident global entry is hit while SATP_ASID != Key_ASID.  Two rounds alternate the
//          ASID pair so that, regardless of replacement order, slot 2 holds a global entry that is
//          hit under a mismatched ASID.
//
//          Self-checking (WALLY-selfcheck.h).  Each fill stores "addi a5, x0, ID; ret" into its
//          page, where ID = (round << 6) | the physical page the VA maps, so every fetch (the fill
//          and the refetch under the other ASID) checks that it ran the code of the right physical
//          page from the current round.  At the end, machine mode reads the 36 physical pages back
//          to check that every store landed in the page its PTE names.  Whether the refetch hits
//          the global entry or walks again is not architecturally visible; either way the mapping
//          must be the same.  Failure indices: 1/3 fill fetch (rounds 1/2), 2/4 refetch under the
//          other ASID, 5 physical page contents, 0xF0 any trap but an ecall.
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
    .8byte 0x200074EF
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
    .8byte 0x200074EF
    .8byte 0x200078EF
    .8byte 0x20007CEF

    .8byte 0x200080EF // access xC002 0000
    .8byte 0x200084EF
    .8byte 0x200088EF
    .8byte 0x20008CEF

#include "WALLY-selfcheck.h"

// VA page i (VA 0xC0000000 + i * 0x1000) maps physical page p (PA 0x80000000 + p * 0x1000), with
// p = i for i < 36 and p = i - 32 for the entries 36-67 that repeat pages 4-35.
#define NPAGES  36
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

    li t3, 48                       # distinct pages per fill (> TLB entries so every line churns)
    li t4, 0x1000                   # offset between pages

    # ---- round 1: fill global pages under ASID=0, then re-fetch under ASID=1 ----
    li s10, 1 << 6                  # round field of the ID
    li t5, 0x9000000000080080       # ASID = 0
    csrw satp, t5
    li t0, 0xC0000000
    li t2, 0
fill0:
    bge t2, t3, swap0
    PAGEOF a3, t2
    or a3, a3, s10                  # a3 = ID of the code this page must run
    CODEWORD t1, a3
    sd t1, 0(t0)                    # store the code into the page (DTLB fill)
    fence.i
    li a5, -1
    jalr t0                         # fetch+execute it (ITLB fill, global entry, Key_ASID=0)
    SC_CHECK_EQ_ADR a5, a3, t0, 1
    add t0, t0, t4
    addi t2, t2, 1
    j fill0
swap0:
    li t5, 0x9001000000080080       # switch to ASID=1, NO sfence: global entries stay resident
    csrw satp, t5
    li t0, 0xC0000000
    li t2, 0
refetch0:
    bge t2, t3, round2
    PAGEOF a3, t2
    or a3, a3, s10
    li a5, -1
    jalr t0                         # ITLB hit on global entry (Key_ASID=0) under SATP_ASID=1 => PTE_G_1 row
    SC_CHECK_EQ_ADR a5, a3, t0, 2
    add t0, t0, t4
    addi t2, t2, 1
    j refetch0

    # ---- round 2: fill global pages under ASID=1, then re-fetch under ASID=0 ----
round2:
    li s10, 2 << 6
    li t5, 0x9001000000080080       # ASID = 1
    csrw satp, t5
    li t0, 0xC0000000
    li t2, 0
fill1:
    bge t2, t3, swap1
    PAGEOF a3, t2
    or a3, a3, s10
    CODEWORD t1, a3
    sd t1, 0(t0)
    fence.i
    li a5, -1
    jalr t0                         # ITLB fill, global entry, Key_ASID=1
    SC_CHECK_EQ_ADR a5, a3, t0, 3
    add t0, t0, t4
    addi t2, t2, 1
    j fill1
swap1:
    li t5, 0x9000000000080080       # switch to ASID=0, NO sfence
    csrw satp, t5
    li t0, 0xC0000000
    li t2, 0
refetch1:
    bge t2, t3, finished
    PAGEOF a3, t2
    or a3, a3, s10
    li a5, -1
    jalr t0                         # ITLB hit on global entry (Key_ASID=1) under SATP_ASID=0 => PTE_G_1 row
    SC_CHECK_EQ_ADR a5, a3, t0, 4
    add t0, t0, t4
    addi t2, t2, 1
    j refetch1

    # ---- every physical page holds the code that round 2 stored through its mapping ----
finished:
    li a0, 3
    ecall                           # machine mode: read the physical pages directly
    li t0, 0x80000000
    li t2, 0
    li a6, NPAGES
sweep:
    or a3, t2, s10
    CODEWORD a4, a3
    ld a5, 0(t0)
    SC_CHECK_EQ_ADR a5, a4, t0, 5
    add t0, t0, t4
    addi t2, t2, 1
    blt t2, a6, sweep

    SC_PASS
    j done
