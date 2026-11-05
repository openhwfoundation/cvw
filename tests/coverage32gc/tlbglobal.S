///////////////////////////////////////////
// tlbglobal.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: Sv32 coverage of every ITLB and DTLB camline (tlbcamline.sv) with kilopage, megapage and
//          global entries, ASID changes and both kinds of sfence.vma, and of the NAPOT4 term of tlb.sv.
//          RV32 counterpart of tests/coverage64gc/tlbGLBASID.S, tlbGLBHIT.S, tlbASIDMISS.S and parts of
//          tlbOverlap.S.  The TLB replaces the first line not recently used, so 64 misses to distinct
//          pages fill all 32 lines of a TLB.
//          VA 0x80200000-0x8025FFFF ("R", 96 kilopages) all map to one physical page, tpage, whose PPN
//          ends in 4'b1000; tpage holds an ecall at offset 0 and a tag word at offset 4.  R2 =
//          VA 0x80E00000-0x80E5FFFF uses the same level-0 table, so R2 page k has R page k's VPN[0] in
//          another megapage.  The DTLB is reached by machine-mode loads with mstatus.MPRV = 1 and MPP = S,
//          the ITLB by an mret to supervisor mode at the page, which runs the ecall and traps back.
//          Each of four rounds r (window W = pages 24+8r..63+8r, a superset of the last 32 pages walked,
//          so the lines shift between rounds):
//            A. ASID 1, not global: walk pages 0..63+8r.  Lookups and walks compare lines of other
//               kilopages in the same megapage (Match0 = 0, Match1 = 1) with the walker's page type 0 and
//               1 (it is 1 between L1_RD and L0_RD).
//            B. ASID 2 with root table root2a, whose entry for the megapage is invalid with G = 0: each W
//               page misses its ASID 1 line on the ASID (MatchASID = 0, Overlap with WritePTE_G = 0).  The
//               first walk faults at the root and the TLB caches the invalid megapage entry, which every
//               later lookup in this step hits, so the ASID 1 lines of W stay for the next step.
//            C. ASID 3 with root2b, whose entry is invalid with G = 1: after the first fault the walker's
//               PTE register holds G = 1, so each W lookup compares its ASID 1 line with WritePTE_G = 1 and
//               MatchASID = 0.  W is looked up twice.
//            D. sfence.vma, which drops the cached invalid global entry; the R leaves become global; ASID 4
//               with the real root table: walk W, so every line is global.
//            E. ASID 5: the global lines (keyed with ASID 4) hit through PTE_G.
//            F. sfence.vma with rs2 = ASID 5 (TLBFlushAll = 0, global lines stay), then sfence.vma x0, x0
//               (TLBFlushAll = 1) with every line global.
//            G. W again: lookups find invalid lines whose keys match (Valid = 0).
//            H. R2 pages of W: lines with the same VPN[0] and another VPN[1] (Match1 = 0).
//          Then 64 aligned megapages (VA 0xC0000000 + i * 4 MiB) fill every line with a megapage, and R
//          lookups compare them with another VPN[0] (PageType > 0).  A megapage leaf with a misaligned
//          PPN ending in 4'b1000 faults on a load and a fetch (tlb.sv NAPOT4 with HitPageType = 1).
//          No PTE ever changes its translation, so a stale TLB entry gives the same result as a walk.
//          Self-checking (WALLY-selfcheck.h): every load returns the tag, every fetch traps with
//          mcause 9 (ecall from S) and mepc = the VA, and each fault (steps B and C, the misaligned
//          megapage) has the expected mcause, mepc and mtval and leaves the load's register unchanged.  Failure index = 1000 * round + 100 * step + check (round 5: megapages, 6: faults);
//          0xF0 for any other trap.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define TAG      0x7A6B5C4D
#define RBASE    0x80200000         // R: 96 kilopages, all aliases of tpage (l0table entries 0x200-0x25F)
#define R2BASE   0x80E00000         // R2: the same level-0 table under root entry 0x203
#define MISMEGA  0x80800000         // misaligned megapage leaf (PPN = tpage's), root entry 0x202
#define MEGABASE 0xC0000000         // 64 megapage leaves, root entries 0x300-0x33F, PA 0x80000000

// SET_SATP asid, root: Sv32 with the given root table and ASID (no sfence.vma)
.macro SET_SATP asid, root=roottable
    la t0, \root
    srli t0, t0, 12
    li t1, 0x80000000 | (\asid << 22)
    or t0, t0, t1
    csrw satp, t0
.endm

// DLOAD va, dst: machine-mode load of the word at va + 4 with the permissions and translation of
// supervisor mode (MPRV = 1, MPP = S).  A load page fault leaves dst unchanged (probe_trap skips the load).
.macro DLOAD va, dst
    li t0, 0x1800
    csrc mstatus, t0
    li t0, 0x20800              # MPRV, MPP = S
    csrs mstatus, t0
    lw \dst, 4(\va)
    li t0, 0x20000
    csrc mstatus, t0
.endm

// FETCH va: enter supervisor mode at va.  The ecall there (or an instruction page fault) traps to
// probe_trap, which records mcause in s10, mepc in s11 and mtval in s8, and resumes here in M mode.
.macro FETCH va
    li t0, 0x1800
    csrc mstatus, t0
    li t0, 0x800                # MPP = S
    csrs mstatus, t0
    csrw mepc, \va
    la s9, 9f
    mret
9:
.endm

// CHECK_PAGE va, index: the load from va returns TAG and the fetch at va traps with an ecall from S at va
.macro CHECK_PAGE va, index
    li t3, 0
    DLOAD \va, t3
    li t4, TAG
    SC_CHECK_EQ_ADR t3, t4, \va, \index
    li s10, 0
    li s11, 0
    FETCH \va
    li t4, 9
    SC_CHECK_EQ_ADR s10, t4, \va, \index+1
    SC_CHECK_EQ_ADR s11, \va, \va, \index+2
.endm

// CHECK_FAULT va, index: the load from va takes a load page fault (13, mtval = va + 4) and leaves its
// register unchanged; the fetch at va takes an instruction page fault (12, mepc = mtval = va)
.macro CHECK_FAULT va, index
    li s10, 0
    li s8, 0
    li t3, 0x55
    DLOAD \va, t3
    li t4, 0x55
    SC_CHECK_EQ_ADR t3, t4, \va, \index
    li t4, 13
    SC_CHECK_EQ_ADR s10, t4, \va, \index+1
    addi t4, \va, 4
    SC_CHECK_EQ_ADR s8, t4, \va, \index+2
    li s10, 0
    li s11, 0
    li s8, 0
    FETCH \va
    li t4, 12
    SC_CHECK_EQ_ADR s10, t4, \va, \index+3
    SC_CHECK_EQ_ADR s11, \va, \va, \index+4
    SC_CHECK_EQ_ADR s8, \va, \va, \index+5
.endm

// ALLFAULT first, last, index: CHECK_FAULT on R pages first..last (uses s1, s2, a3)
.macro ALLFAULT first, last, index
    li s1, \first
    li s2, \last
1:  slli t2, s1, 12
    li a3, RBASE
    add a3, a3, t2
    CHECK_FAULT a3, \index
    addi s1, s1, 1
    ble s1, s2, 1b
.endm

// ALLPAGES base, shift, first, last, index: CHECK_PAGE on VA base + (k << shift) for k = first..last
// (uses s1, s2, a3)
.macro ALLPAGES base, shift, first, last, index
    li s1, \first
    li s2, \last
1:  slli t2, s1, \shift
    li a3, \base
    add a3, a3, t2
    CHECK_PAGE a3, \index
    addi s1, s1, 1
    ble s1, s2, 1b
.endm

// R_FLAGS flags: rewrite the 96 R leaves with tpage's PPN and the given flags (no sfence.vma)
.macro R_FLAGS flags
    la t0, l0table
    li t1, 0x200 * 4
    add t0, t0, t1              # l0 entry 0x200: VA 0x80200000
    la t1, tpage
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, \flags
    li t2, 96
1:  sw t1, 0(t0)
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, 1b
.endm

// ROUND r: steps A-H above on window W = R pages 24+8r..63+8r
.macro ROUND r
    R_FLAGS 0xCF                # V R W X A D, not global
    SET_SATP 1
    sfence.vma
    ALLPAGES RBASE, 12, 0, 63+8*\r, 1000*\r+100                     # A
    SET_SATP 2, root2a
    ALLFAULT 24+8*\r, 63+8*\r, 1000*\r+200                          # B
    SET_SATP 3, root2b
    ALLFAULT 24+8*\r, 63+8*\r, 1000*\r+300                          # C
    ALLFAULT 24+8*\r, 63+8*\r, 1000*\r+310
    R_FLAGS 0xEF                # V R W X G A D
    SET_SATP 4
    sfence.vma                  # drop the invalid global megapage entry that step C cached
    ALLPAGES RBASE, 12, 24+8*\r, 63+8*\r, 1000*\r+400              # D
    SET_SATP 5
    ALLPAGES RBASE, 12, 24+8*\r, 63+8*\r, 1000*\r+500              # E
    li t2, 5
    sfence.vma zero, t2         # F: ASID 5 only
    sfence.vma                  #    every address space
    ALLPAGES RBASE, 12, 24+8*\r, 63+8*\r, 1000*\r+700              # G
    ALLPAGES R2BASE, 12, 24+8*\r, 63+8*\r, 1000*\r+800             # H
.endm

main:
    la t0, probe_trap
    csrw mtvec, t0

    // Page tables.  l0table maps VA 0x80000000-0x801FFFFF to itself with kilopages (not used for
    // fetches, which run in M mode, but it shares the megapage with R) and R to tpage.
    la t0, l0table
    li t1, 0x80000              # PPN of 0x80000000
    li t2, 512
1:  slli t3, t1, 10
    ori t3, t3, 0xCF            # V R W X A D
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, 1b
    R_FLAGS 0xCF                # R: V R W X A D, not global
    la t0, roottable
    li t1, 0x200 * 4
    add t0, t0, t1              # root entry 0x200
    la t1, l0table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1               # non-leaf
    sw t1, 0(t0)                # VA 0x80000000-0x803FFFFF -> l0table
    sw t1, 12(t0)               # VA 0x80C00000-0x80FFFFFF -> l0table (R2)
    la t1, tpage
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 0xCF
    sw t1, 8(t0)                # VA 0x80800000: megapage leaf with a misaligned PPN
    la t0, roottable
    li t1, 0x300 * 4
    add t0, t0, t1              # root entries 0x300-0x33F: megapage leaves, PA 0x80000000
    li t1, (0x80000 << 10) | 0xCF
    li t2, 64
1:  sw t1, 0(t0)
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, 1b
    // root2a and root2b: the entry for VA 0x80000000-0x803FFFFF is invalid, with G = 0 and G = 1
    la t0, root2a
    li t1, 0x200 * 4
    add t0, t0, t1
    sw zero, 0(t0)
    la t0, root2b
    add t0, t0, t1
    li t2, 0x20                 # G, V = 0
    sw t2, 0(t0)

    ROUND 0
    ROUND 1
    ROUND 2
    ROUND 3

    // 64 megapages fill every line; then R lookups compare them with another VPN[0]
    R_FLAGS 0xCF
    SET_SATP 1
    sfence.vma
    li s3, MEGABASE
    la t0, tpage
    li t1, 0x80000000
    sub t0, t0, t1
    add s3, s3, t0              # tpage's offset in each megapage
    li s1, 0
    li s2, 64
2:  slli t2, s1, 22
    add a3, s3, t2
    CHECK_PAGE a3, 5000
    addi s1, s1, 1
    blt s1, s2, 2b
    ALLPAGES RBASE, 12, 0, 31, 5100

    // misaligned megapage: load page fault (13) and instruction page fault (12)
    la a3, tpage
    li t1, MISMEGA - 0x80000000
    add a3, a3, t1
    li s10, 0
    li s8, 0
    li t3, 0x55
    DLOAD a3, t3
    li t4, 0x55
    SC_CHECK_EQ t3, t4, 6000    # the faulting load wrote nothing
    li t4, 13
    SC_CHECK_EQ s10, t4, 6001
    addi t4, a3, 4
    SC_CHECK_EQ s8, t4, 6002    # mtval = load address
    li s10, 0
    li s11, 0
    FETCH a3
    li t4, 12
    SC_CHECK_EQ s10, t4, 6003
    SC_CHECK_EQ s11, a3, 6004   # mepc = fetch address
    SC_CHECK_EQ s8, a3, 6005    # mtval = fetch address

    csrw satp, zero
    sfence.vma
    la t0, trap_handler
    csrw mtvec, t0
    SC_PASS
    j done

// Supervisor fetches end in an ecall from S (9) or an instruction page fault (12): record them and
// resume the test in machine mode at s9.  Load page faults (13) from DLOAD: record and skip the load.
// Everything else (including the ecall that ends the test) goes to sc_trap_handler, which passes
// ecalls to the library handler and fails the test on any other trap.
.align 4
probe_trap:
    csrr s10, mcause
    csrr s11, mepc
    csrr s8, mtval
    li t6, 13
    beq s10, t6, 1f
    li t6, 9
    beq s10, t6, 2f
    li t6, 12
    beq s10, t6, 2f
    j sc_trap_handler
1:  addi t6, s11, 4
    csrw mepc, t6
    mret
2:  jr s9

.data
.p2align 12
roottable:
    .fill 1024, 4, 0
root2a:
    .fill 1024, 4, 0
root2b:
    .fill 1024, 4, 0
l0table:
    .fill 1024, 4, 0
// tpage: PPN[3:0] = 4'b1000
.p2align 16
    .skip 0x8000
tpage:
    ecall
    .word TAG
    .fill 1022, 4, 0
