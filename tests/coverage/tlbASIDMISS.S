///////////////////////////////////////////
// tlbASIDMISS.S
//
// Written: David_Harris@hmc.edu 2 June 2026
//
// Purpose: Close the last uncovered FEC row in IFU TLB camline slot 30:
//          tlbcamline.sv  assign Match = Valid & MatchASID & Match0 & Match1 & Match2 & Match3 & Match4;
//          Row 11: MatchASID_0 with non-masking condition (Valid && Match0..Match4 all 1) -- i.e. a
//          *non-global* entry whose virtual-page tag fully matches the lookup and that is Valid, but
//          whose stored Key_ASID differs from SATP_ASID, so MatchASID = (SATP_ASID==Key_ASID)|PTE_G = 0
//          and the line correctly MISSES purely on the ASID.
//
//          This is the non-global counterpart of tlbGLBHIT.S (which covers the PTE_G_1 *hit* row using
//          global pages).  Here the L0 leaves are non-global (G=0, 0x..CF): fill every ITLB line with
//          non-global pages under one ASID, switch ASID WITHOUT an sfence (the non-global entries stay
//          resident -- writing satp does not flush the TLB), then re-fetch the same pages so each
//          resident entry is looked up with Key_ASID != SATP_ASID, producing MatchASID_0.  Two rounds
//          alternate the ASID pair so that, regardless of replacement order, slot 30 holds a non-global
//          entry that is looked up under a mismatched ASID.  The running code lives on the *global*
//          gigapage (L2[2]=0x..EF) so it keeps fetching across the ASID switch.
//
//          Self-checking (WALLY-selfcheck.h).  The two ASIDs have their own page tables, which map
//          the VA pages to different physical pages: ASID 0 to set A (0x80000000 + p * 0x1000) and
//          ASID 1 to set B (0x80040000 + p * 0x1000).  Every physical page holds the code
//          "addi a5, x0, ID; ret", ID = (set << 6) | p, preloaded in machine mode, and each fill
//          stores it again with WRITTEN (0x80) added.  The fill fetch must run the code just stored
//          (exact ID), and the refetch under the other ASID must run its own set's page (ID without
//          WRITTEN), so a stale entry of the other ASID that wrongly hits is caught.  At the end,
//          machine mode checks that every page of both sets holds its own code with WRITTEN, so no
//          store went to a page of the wrong set.  The pointer PTEs are non-global: a global
//          pointer would make the leaves below it global, and global mappings must be the same in
//          every address space.  Failure indices: 1 fill fetch, 2 refetch under the other ASID,
//          3 set A contents, 4 set B contents, 0xF0 any trap but an ecall.
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
// addresses that satp and the pointer PTEs name (0x80080000-0x80087FFF).
.data
.align 19
# ASID 0: level 3 Page table situated at 0x80080000, points to 0x80081000
pagetable:
    .8byte 0x20020401

.align 12 // level 2 page table, contains direction to a gigapage
    .8byte 0x0
    .8byte 0x0
    .8byte 0x200000EF // global gigapage 8000 0000 - C000 0000: holds the running test code
    .8byte 0x20020801 // pointer to next page table entry at 8008 2000 (non-global)

.align 12 // level 1 page table, points to level 0 page table
    .8byte 0x20020C01 // non-global

.align 12 // level 0 page table, contains 64 NON-GLOBAL (G=0, 0x..CF) kilopages
    .8byte 0x200000CF // access xC000 0000
    .8byte 0x200004CF // access xC000 1000
    .8byte 0x200008CF // access xC000 2000
    .8byte 0x20000CCF // access xC000 3000

    .8byte 0x200010CF // access xC000 4000
    .8byte 0x200014CF
    .8byte 0x200018CF
    .8byte 0x20001CCF

    .8byte 0x200020CF // access xC000 8000
    .8byte 0x200024CF
    .8byte 0x200028CF
    .8byte 0x20002CCF

    .8byte 0x200030CF // access xC000 C000
    .8byte 0x200034CF
    .8byte 0x200038CF
    .8byte 0x20003CCF

    .8byte 0x200040CF // access xC001 0000
    .8byte 0x200044CF
    .8byte 0x200048CF
    .8byte 0x20004CCF

    .8byte 0x200050CF // access xC001 4000
    .8byte 0x200054CF
    .8byte 0x200058CF
    .8byte 0x20005CCF

    .8byte 0x200060CF // access xC001 8000
    .8byte 0x200064CF
    .8byte 0x200068CF
    .8byte 0x20006CCF

    .8byte 0x200070CF // access xC001 C000
    .8byte 0x200074CF
    .8byte 0x200078CF
    .8byte 0x20007CCF

    .8byte 0x200080CF // access xC002 0000
    .8byte 0x200084CF
    .8byte 0x200088CF
    .8byte 0x20008CCF

    .8byte 0x200010CF // access xC000 4000
    .8byte 0x200014CF
    .8byte 0x200018CF
    .8byte 0x20001CCF

    .8byte 0x200020CF // access xC000 8000
    .8byte 0x200024CF
    .8byte 0x200028CF
    .8byte 0x20002CCF

    .8byte 0x200030CF // access xC000 C000
    .8byte 0x200034CF
    .8byte 0x200038CF
    .8byte 0x20003CCF

    .8byte 0x200040CF // access xC001 0000
    .8byte 0x200044CF
    .8byte 0x200048CF
    .8byte 0x20004CCF

    .8byte 0x200050CF // access xC001 4000
    .8byte 0x200054CF
    .8byte 0x200058CF
    .8byte 0x20005CCF

    .8byte 0x200060CF // access xC001 8000
    .8byte 0x200064CF
    .8byte 0x200068CF
    .8byte 0x20006CCF

    .8byte 0x200070CF // access xC001 C000
    .8byte 0x200074CF
    .8byte 0x200078CF
    .8byte 0x20007CCF

    .8byte 0x200080CF // access xC002 0000
    .8byte 0x200084CF
    .8byte 0x200088CF
    .8byte 0x20008CCF

# ASID 1: the same structure at 0x80084000, with the kilopages at VA 0xC0000000 mapping set B
.align 12 // level 3 page table at 0x80084000, points to 0x80085000
    .8byte 0x20021401

.align 12 // level 2 page table
    .8byte 0x0
    .8byte 0x0
    .8byte 0x200000EF // the same global gigapage 8000 0000 - C000 0000
    .8byte 0x20021801 // pointer to the level 1 page table at 8008 6000 (non-global)

.align 12 // level 1 page table, points to level 0 page table at 8008 7000
    .8byte 0x20021C01 // non-global

.align 12 // level 0 page table: VA page i -> set B page p (0x80040000 + p * 0x1000), non-global
    .8byte 0x200100CF // access xC000 0000 -> 0x80040000
    .8byte 0x200104CF
    .8byte 0x200108CF
    .8byte 0x20010CCF

    .8byte 0x200110CF // access xC000 4000 -> 0x80044000
    .8byte 0x200114CF
    .8byte 0x200118CF
    .8byte 0x20011CCF

    .8byte 0x200120CF // access xC000 8000 -> 0x80048000
    .8byte 0x200124CF
    .8byte 0x200128CF
    .8byte 0x20012CCF

    .8byte 0x200130CF // access xC000 C000 -> 0x8004C000
    .8byte 0x200134CF
    .8byte 0x200138CF
    .8byte 0x20013CCF

    .8byte 0x200140CF // access xC001 0000 -> 0x80050000
    .8byte 0x200144CF
    .8byte 0x200148CF
    .8byte 0x20014CCF

    .8byte 0x200150CF // access xC001 4000 -> 0x80054000
    .8byte 0x200154CF
    .8byte 0x200158CF
    .8byte 0x20015CCF

    .8byte 0x200160CF // access xC001 8000 -> 0x80058000
    .8byte 0x200164CF
    .8byte 0x200168CF
    .8byte 0x20016CCF

    .8byte 0x200170CF // access xC001 C000 -> 0x8005C000
    .8byte 0x200174CF
    .8byte 0x200178CF
    .8byte 0x20017CCF

    .8byte 0x200180CF // access xC002 0000 -> 0x80060000
    .8byte 0x200184CF
    .8byte 0x200188CF
    .8byte 0x20018CCF

    .8byte 0x200110CF // access xC002 4000 -> 0x80044000
    .8byte 0x200114CF
    .8byte 0x200118CF
    .8byte 0x20011CCF

    .8byte 0x200120CF // access xC002 8000 -> 0x80048000
    .8byte 0x200124CF
    .8byte 0x200128CF
    .8byte 0x20012CCF

    .8byte 0x200130CF // access xC002 C000 -> 0x8004C000
    .8byte 0x200134CF
    .8byte 0x200138CF
    .8byte 0x20013CCF

    .8byte 0x200140CF // access xC003 0000 -> 0x80050000
    .8byte 0x200144CF
    .8byte 0x200148CF
    .8byte 0x20014CCF

    .8byte 0x200150CF // access xC003 4000 -> 0x80054000
    .8byte 0x200154CF
    .8byte 0x200158CF
    .8byte 0x20015CCF

    .8byte 0x200160CF // access xC003 8000 -> 0x80058000
    .8byte 0x200164CF
    .8byte 0x200168CF
    .8byte 0x20016CCF

    .8byte 0x200170CF // access xC003 C000 -> 0x8005C000
    .8byte 0x200174CF
    .8byte 0x200178CF
    .8byte 0x20017CCF

    .8byte 0x200180CF // access xC004 0000 -> 0x80060000
    .8byte 0x200184CF
    .8byte 0x200188CF
    .8byte 0x20018CCF

#include "WALLY-selfcheck.h"

// VA page i (VA 0xC0000000 + i * 0x1000) maps physical page p of the ASID's set, with p = i for
// i < 36 and p = i - 32 for the entries 36-67 that repeat pages 4-35.
#define NPAGES  36
#define WRITTEN 0x80                    // added to the ID of the code a fill stores
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

// PRELOAD adr, first, id: store the code with ID id | p at adr + p * 0x1000 for p = first-35 (clobbers a1-a4)
.macro PRELOAD adr, first, id
    li a1, \adr + \first * 0x1000
    li a2, \first
1:  ori a3, a2, \id
    CODEWORD a4, a3
    sd a4, 0(a1)
    li a3, 0x1000
    add a1, a1, a3
    addi a2, a2, 1
    li a3, NPAGES
    blt a2, a3, 1b
.endm

// SWEEP adr, id, index: check that adr + p * 0x1000 holds the code with ID id | p for p = 0-35
.macro SWEEP adr, id, index
    li t0, \adr
    li t2, 0
1:  ori a3, t2, \id
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

    # Preload the code of every physical page that a refetch can reach before a fill stores it.
    # Set A pages 0 and 1 are left alone (they hold the entry code and tohost); the first fill
    # stores them before any refetch under ASID 0.
    PRELOAD 0x80000000, 2, 0 << 6
    PRELOAD 0x80040000, 0, 1 << 6
    fence.i

    # Page table root address at 0x80080000, ASID = 0 (SV48)
    li t5, 0x9000000000080080
    csrw satp, t5

    # switch to supervisor mode
    li a0, 1
    ecall

    # A non-global re-fetch MISSES (MatchASID_0) and then installs a new-ASID entry, evicting per the
    # bit-PLRU.  So MatchASID_0 only fires for whichever camline still holds the stale entry at probe
    # time, and the running code's global gigapage pins one slot -- which camline gets caught depends on
    # the fill/refetch alignment.  To reach EVERY camline (slot 30 is the lone holdout in the merged
    # report), sweep the distinct-page count across rounds and alternate the ASID pair each round.
    li t4, 0x1000                   # offset between pages
    li s2, 0                        # ASID toggle (0/1) for the fill phase
    li s3, 24                       # current distinct-page count (swept)
    li s4, 49                       # one past the largest distinct-page count

outer:
    bge s3, s4, finished

    # build satp values: base (MODE=SV48, PPN=0x80080) with ASID = s2 (fill) and 1-s2 (refetch);
    # ASID 1 uses the page table at 0x80084000 (PPN + 4)
    li s0, 0x9000000000080080
    slli t5, s2, 44                 # fill-phase ASID in satp[59:44]
    or  t5, s0, t5                  # satp for fill phase
    slli a6, s2, 2
    add t5, t5, a6
    xori s1, s2, 1
    slli t6, s1, 44                 # refetch-phase ASID
    or  t6, s0, t6                  # satp for refetch phase
    slli a6, s1, 2
    add t6, t6, a6
    slli s5, s2, 6
    ori s5, s5, WRITTEN             # ID fields of the code the fill stores
    slli s6, s1, 6                  # ID field of the refetch ASID's set

    # fill s3 distinct non-global pages under the fill ASID (store code, then fetch+execute it)
    csrw satp, t5
    li t0, 0xC0000000
    li t2, 0
fill:
    bge t2, s3, swap
    PAGEOF a3, t2
    or a3, a3, s5                   # a3 = ID of the code this page must run
    CODEWORD t1, a3
    sd t1, 0(t0)                    # DTLB fill
    fence.i
    li a5, -1
    jalr t0                         # ITLB fill: non-global entry, Key_ASID = fill ASID
    SC_CHECK_EQ_ADR a5, a3, t0, 1
    add t0, t0, t4
    addi t2, t2, 1
    j fill
swap:
    csrw satp, t6                   # switch ASID, NO sfence: the non-global entries stay resident
    li t0, 0xC0000000
    li t2, 0
refetch:
    bge t2, s3, nextround
    PAGEOF a3, t2
    or a3, a3, s6                   # the refetch ASID's page, whether or not a fill has stored it yet
    li a5, -1
    jalr t0                         # ITLB lookup: Key_ASID != SATP_ASID and PTE_G=0 => MatchASID_0
    andi a7, a5, ~WRITTEN
    SC_CHECK_EQ_ADR a7, a3, t0, 2
    add t0, t0, t4
    addi t2, t2, 1
    j refetch

nextround:
    xori s2, s2, 1                  # alternate the ASID pair
    addi s3, s3, 1                  # next distinct-page count
    j outer

    # ---- every page of both sets holds its own code, stored by the last fill of its ASID ----
finished:
    li a0, 3
    ecall                           # machine mode: read the physical pages directly
    SWEEP 0x80000000, WRITTEN | (0 << 6), 3
    SWEEP 0x80040000, WRITTEN | (1 << 6), 4

    SC_PASS
    j done
