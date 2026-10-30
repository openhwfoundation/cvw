///////////////////////////////////////////
// tlbOverlap.S
//
// Written David_Harris@hmc.edu 10/16/26
//
// Purpose: Exercise the Overlap check of every ITLB and DTLB line: while each line holds a valid entry, the
//          walker reads a PTE that may cover the same address, for each way the check can match:
//            A. a 64 KiB NAPOT leaf in the 64 KiB region of the line's 4 KiB page (the line is invalidated)
//            B. a NAPOT leaf in the same megapage but another 64 KiB region (the line stays)
//            C. a global gigapage leaf read under another ASID, in the line's gigapage (the line is invalidated)
//            D. an Sv57 petapage leaf for a VA that shares the line's VPN[4] but not its VPN[3] (likewise)
//          The TLB replaces the first line not recently used, and clears the recently-used bits once every line
//          has been used.  The access replayed after a miss hits the line just written, so when that write
//          cleared the bits, the line is marked again and the next 31 writes pass over it.  62 misses to
//          distinct pages therefore fill every line.  In part A, each NAPOT walk's write evicts a line that
//          may hold a page of a region not walked yet, so part A runs twice, with 62 and 64 pages, which
//          leaves the replacement pointer in different places.  An SFENCE.VMA does not change the bits.
//          The DTLB is reached by M-mode loads with mstatus.MPRV = 1 and MPP = S; the ITLB by entering S mode at
//          the page, which runs addi a1, x0, <page>; ecall.  Every access checks the page it reached, through
//          the tag stored in that physical page (loads) or the page number the code returns (fetches).
//          The DTLB sees the walker's PTE addresses during a walk, so its lines are checked against the leaf
//          when the load replays: part C ends in a global gigapage leaf and part D in a petapage leaf.
//          Where a part rewrites a PTE without an SFENCE.VMA (the NAPOT PTEs of part A, the petapage leaf of
//          part D), the next access has not been cached and the old and new PTEs map it to the same physical
//          page, so either translation gives the same result.  Under ASID 2 (part C) the address is mapped
//          only by the global gigapage.
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

#define VA_MA    0x40000000           // megapage A: VPN[2] = 1, VPN[1] = 0
#define VA_MB    0x40200000           // megapage B: VPN[2] = 1, VPN[1] = 1
#define VA57_A   0x0001008040200000   // Sv57: VPN[4] = 1, VPN[3] = 1, then megapage B
#define VA57_HI  0x0001000000000000   // Sv57: VPN[4] = 1; the petapage maps VA57_HI + x to x
#define TAG      0x5A5A0000           // physical page j holds TAG + j at offset 8
#define PTE_RWX  0xCF                 // V R W X A D
#define PTE_PTR  0x01                 // non-leaf
#define PTE_G    0x20
#define NVICT    62                   // misses that fill every line

// rd = PTE pointing to the table at label, with extra flag bits
.macro PTR rd, label, flags
    la \rd, \label
    srli \rd, \rd, 12
    slli \rd, \rd, 10
    ori \rd, \rd, PTE_PTR | \flags
.endm

// satp = mode | asid | root
.macro SATP mode, asid, root
    la t0, \root
    srli t0, t0, 12
    li t1, (\mode << 60) | (\asid << 44)
    or t0, t0, t1
    csrw satp, t0
.endm

// access pages first..last of base: page p maps to physical page p & 31
.macro ACCESS_RANGE base, first, last
    li s1, \first
1:  li a2, \base
    slli t0, s1, 12
    add a2, a2, t0
    andi a3, s1, 31
    jal ra, access
    addi s1, s1, 1
    li t0, \last
    ble s1, t0, 1b
.endm

// access page p of base, expecting physical page phys
.macro ACCESS_ONE base, p, phys
    li a2, \base + (\p << 12)
    li a3, \phys
    jal ra, access
.endm

// a2 = base + physical address of page 16, expecting page 16
.macro ACCESS_PHYS16 base
    la a2, vpages + (16 << 12)
    li t0, \base
    add a2, a2, t0
    li a3, 16
    jal ra, access
.endm

main:
    SC_STRICT_TRAPS
    li s0, 0                    # DTLB
    jal ra, sequence
    la t0, itlb_handler
    csrw mtvec, t0
    li s0, 1                    # ITLB
    jal ra, sequence
    SC_STRICT_TRAPS
    SC_PASS
    j done

// Run parts A-D on the TLB s0 selects
sequence:
    mv s10, ra
    jal ra, init_tables
    SATP 8, 1, root1            # Sv39, ASID 1
    sfence.vma
    ACCESS_RANGE VA_MB, 16, 47

    # A. NAPOT leaves in the 64 KiB regions of the lines' pages
    li a6, NVICT
    jal ra, partA
    li a6, NVICT + 2
    jal ra, partA

    # B. a NAPOT leaf in another 64 KiB region of the lines' megapage
    sfence.vma
    ACCESS_RANGE VA_MB, 16, 16 + NVICT - 1  # regions 1-4 of megapage B
    ACCESS_ONE VA_MB, 0, 0                  # region 0 is a NAPOT page

    # C. a global gigapage leaf under another ASID, in the lines' gigapage
    sfence.vma
    ACCESS_RANGE VA_MB, 16, 16 + NVICT - 1
    SATP 8, 2, root2            # Sv39, ASID 2
    ACCESS_PHYS16 (VA_MA - 0x80000000)      # the gigapage maps VA_MA + x to 0x80000000 + x

    # D. an Sv57 petapage leaf for a VA with the lines' VPN[4] and another VPN[3]
    SATP 10, 3, root57          # Sv57, ASID 3
    sfence.vma
    ACCESS_RANGE VA57_A, 16, 16 + NVICT - 1
    li t0, PTE_RWX              # root57[1] becomes a petapage on physical address 0; no SFENCE.VMA
    la t1, root57
    sd t0, 8(t1)
    ACCESS_PHYS16 VA57_HI       # VPN[3] = 0: through the petapage, or the old gigapage, to page 16

    csrw satp, zero
    sfence.vma
    mv ra, s10
    ret

// Part A with a6 pages: pages 1-15 of the 64 KiB regions of megapage A in turn, then a NAPOT walk in each
partA:
    mv s8, ra
    la a0, LA
    li a1, 0
    li a5, 80
    jal ra, plain               # regions 0-4 of megapage A as 4 KiB pages
    sfence.vma
    li s2, 0                    # pages accessed
    li s3, 0                    # region base page
2:  addi s1, s3, 1
3:  li a2, VA_MA
    slli t0, s1, 12
    add a2, a2, t0
    andi a3, s1, 31
    jal ra, access
    addi s2, s2, 1
    beq s2, a6, 4f
    addi s1, s1, 1
    addi t0, s3, 16
    blt s1, t0, 3b
    addi s3, s3, 16
    j 2b
4:  la a0, LA                   # region r becomes a NAPOT page on physical pages 16 * (r & 1) + 0-15
    li s3, 0
5:  andi a1, s3, 16
    slli t0, s3, 3
    add a0, a0, t0
    jal ra, napot
    la a0, LA
    addi s3, s3, 16
    li t0, 80
    blt s3, t0, 5b
    li s3, 0
6:  li a2, VA_MA                # each region's first page misses and reads its NAPOT PTE
    slli t0, s3, 12
    add a2, a2, t0
    andi a3, s3, 31
    jal ra, access
    addi s3, s3, 16
    li t0, 80
    blt s3, t0, 6b
    mv ra, s8
    ret

// Access VA a2 through the TLB s0 selects and check that it reached physical page a3.  Clobbers t0-t2, a1, s11.
access:
    li t0, 0x1800
    csrc mstatus, t0
    li t0, 0x800
    csrs mstatus, t0            # mstatus.MPP = S
    bnez s0, access_fetch
    li t0, 0x20000
    csrs mstatus, t0            # mstatus.MPRV = 1: the load translates as in S mode
    ld t2, 8(a2)
    csrc mstatus, t0
    li t1, TAG
    add t1, t1, a3
    SC_CHECK_EQ_ADR t2, t1, a2, 1
    ret
access_fetch:
    la s11, access_back         # itlb_handler returns here
    csrw mepc, a2
    mret                        # S mode at a2: addi a1, x0, <page>; ecall
access_back:
    SC_CHECK_EQ_ADR a1, a3, a2, 2
    ret

// The page's ecall from S mode ends the fetch access; any other trap fails the test
.align 4
itlb_handler:
    csrr a4, mcause
    li a5, 9
    bne a4, a5, 1f
    jr s11
1:  la t0, trap_handler
    csrw mtvec, t0
    SC_CHECK_EQ a4, a5, 3

// Write 16 NAPOT PTEs at a0 mapping a 64 KiB region to physical pages a1-a1+15
napot:
    la t0, vpages
    srli t0, t0, 12
    add t0, t0, a1
    ori t0, t0, 8               # PPN[3:0] = 1000
    slli t0, t0, 10
    li t1, 1
    slli t1, t1, 63             # N
    or t0, t0, t1
    ori t0, t0, PTE_RWX
    li t1, 0
1:  slli t2, t1, 3
    add t2, t2, a0
    sd t0, 0(t2)
    addi t1, t1, 1
    li t2, 16
    blt t1, t2, 1b
    ret

// Build the page tables
//   Sv39: root1[1] -> T1; T1[0] -> LA (megapage A), T1[1] -> LB (megapage B)
//         root2[1] = global gigapage on 0x80000000
//   Sv57: root57[1] -> L3; L3[1] -> T2; T2[1] -> T1 (the lines' pages)
//         L3[0] -> T2B; T2B[2] = gigapage on 0x80000000 (the old translation of part D's last access)
//   LB: pages 0-15 are a NAPOT page on physical pages 0-15; pages 16-95 map to physical page p & 31
//   (partA writes LA)
init_tables:
    mv s9, ra
    PTR t0, T1, 0
    la t1, root1
    sd t0, 8(t1)
    li t0, (0x80000000 >> 2) | PTE_G | PTE_RWX
    la t1, root2
    sd t0, 8(t1)
    PTR t0, LA, 0
    la t1, T1
    sd t0, 0(t1)
    PTR t0, LB, 0
    sd t0, 8(t1)
    PTR t0, L3, 0
    la t1, root57
    sd t0, 8(t1)
    PTR t0, T2, 0
    la t1, L3
    sd t0, 8(t1)
    PTR t0, T2B, 0
    sd t0, 0(t1)
    PTR t0, T1, 0
    la t1, T2
    sd t0, 8(t1)
    li t0, (0x80000000 >> 2) | PTE_RWX
    la t1, T2B
    sd t0, 16(t1)
    la a0, LB
    li a1, 0
    jal ra, napot
    la a0, LB
    li a1, 16
    li a5, 96
    jal ra, plain
    mv ra, s9
    ret

// Write 4 KiB PTEs for pages a1 to a5-1 of the table at a0, page p mapping to physical page p & 31
plain:
    la t1, vpages
    srli t1, t1, 12
1:  andi t0, a1, 31
    add t0, t0, t1
    slli t0, t0, 10
    ori t0, t0, PTE_RWX
    slli t2, a1, 3
    add t2, t2, a0
    sd t0, 0(t2)
    addi a1, a1, 1
    blt a1, a5, 1b
    ret

.data
// 32 physical pages: page j starts with addi a1, x0, j; ecall and holds TAG + j at offset 8
.align 16
vpages:
.option push
.option norvc
.set vp, 0
.rept 32
    addi a1, x0, vp
    ecall
    .dword TAG + vp
    .fill 4096 - 16, 1, 0
.set vp, vp + 1
.endr
.option pop

.align 12
root1:
    .fill 512, 8, 0
root2:
    .fill 512, 8, 0
root57:
    .fill 512, 8, 0
L3:
    .fill 512, 8, 0
T2:
    .fill 512, 8, 0
T2B:
    .fill 512, 8, 0
T1:
    .fill 512, 8, 0
LA:
    .fill 512, 8, 0
LB:
    .fill 512, 8, 0
