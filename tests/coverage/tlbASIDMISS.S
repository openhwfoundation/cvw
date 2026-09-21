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

    # A non-global re-fetch MISSES (MatchASID_0) and then installs a new-ASID entry, evicting per the
    # bit-PLRU.  So MatchASID_0 only fires for whichever camline still holds the stale entry at probe
    # time, and the running code's global gigapage pins one slot -- which camline gets caught depends on
    # the fill/refetch alignment.  To reach EVERY camline (slot 30 is the lone holdout in the merged
    # report), sweep the distinct-page count across rounds and alternate the ASID pair each round.
    li t4, 0x1000                   # offset between pages
    li t1, 0x00008067               # "ret" (jalr x0, x1, 0) instruction word
    li s2, 0                        # ASID toggle (0/1) for the fill phase
    li s3, 24                       # current distinct-page count (swept)
    li s4, 49                       # one past the largest distinct-page count

outer:
    bge s3, s4, finished

    # build satp values: base (MODE=SV48, PPN=0x80080) with ASID = s2 (fill) and 1-s2 (refetch)
    li s0, 0x9000000000080080
    slli t5, s2, 44                 # fill-phase ASID in satp[59:44]
    or  t5, s0, t5                  # satp for fill phase
    xori s1, s2, 1
    slli t6, s1, 44                 # refetch-phase ASID
    or  t6, s0, t6                  # satp for refetch phase

    # fill s3 distinct non-global pages under the fill ASID (store a ret, then fetch+execute it)
    csrw satp, t5
    li t0, 0xC0000000
    li t2, 0
fill:
    bge t2, s3, swap
    sw t1, 0(t0)                    # DTLB fill
    fence.i
    jalr t0                         # ITLB fill: non-global entry, Key_ASID = fill ASID
    add t0, t0, t4
    addi t2, t2, 1
    j fill
swap:
    csrw satp, t6                   # switch ASID, NO sfence: the non-global entries stay resident
    li t0, 0xC0000000
    li t2, 0
refetch:
    bge t2, s3, nextround
    jalr t0                         # ITLB lookup: Key_ASID != SATP_ASID and PTE_G=0 => MatchASID_0
    add t0, t0, t4
    addi t2, t2, 1
    j refetch

nextround:
    xori s2, s2, 1                  # alternate the ASID pair
    addi s3, s3, 1                  # next distinct-page count
    j outer

finished:
    j done

.data
.align 19
# level 3 Page table situated at 0x80080000, points to 0x80081000
pagetable:
    .8byte 0x20020401

.align 12 // level 2 page table, contains direction to a gigapage
    .8byte 0x0
    .8byte 0x0
    .8byte 0x200000EF // global gigapage 8000 0000 - C000 0000: holds the running test code
    .8byte 0x20020821 // pointer to next page table entry at 8008 2000

.align 12 // level 1 page table, points to level 0 page table
    .8byte 0x20020C21

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
