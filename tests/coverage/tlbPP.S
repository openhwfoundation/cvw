///////////////////////////////////////////
// tlbPP.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for petapages in the instruction TLB.  Sv57 adds a fifth page table
//          level, so a leaf at the root maps a petapage and the TLB CAM must match on the
//          fourth VPN segment by page type rather than by key.  Executing from more petapages
//          than there are TLB entries puts a petapage in every entry, including the last.
//          This is the Sv57 counterpart of tlbTP.S, which does the same for Sv48 terapages.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"

main:
    // Root entries 0-63 are leaf petapages with PPN = 0, so petapage i maps virtual address
    // (i << 48) + x to physical address x: each of the 64 virtual addresses below reaches the
    // same physical scratch page through a different petapage.  Root entry 64 points at a
    // level-3 table whose entry 1 is a terapage, also with PPN = 0, so (64 << 48) + (1 << 39) + x
    // reaches the scratch page too but with a different VPN[3]; looking that up makes every
    // petapage entry match on page type rather than on its VPN[3] key.
    la t0, pagetable
    la t1, l3table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1               # non-leaf
    sd t1, 64*8(t0)
    srli t0, t0, 12
    li t1, 0xA000000000000000   # MODE = 10, Sv57
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
    li a0, 1
    ecall                       # supervisor mode, where the translation applies

    // Put a ret in the scratch page and make it visible to instruction fetch.
    la t0, scratch
    li t1, 0x00008067           # ret
    sw t1, 0(t0)
    fence.i

    li t2, 0                    # i = 0
    li t3, 64                   # more than the 32 TLB entries, so every entry holds a petapage
    li t4, 1
    slli t4, t4, 48             # petapage stride
    li t6, 64
    slli t6, t6, 48
    li a1, 1
    slli a1, a1, 39
    or t6, t6, a1
    add t6, t6, t0              # (64 << 48) + (1 << 39) + scratch, through the terapage
loop:
    bge t2, t3, finished
    mul t5, t2, t4
    add t5, t5, t0              # (i << 48) + scratch
    jalr ra, t5, 0              # fetch through petapage i
    jalr ra, t6, 0              # then a lookup with a different VPN[3] against every entry
    addi t2, t2, 1
    j loop
finished:
    csrw satp, zero
    sfence.vma
    li a0, 3
    ecall                       # back to machine mode
    j done

.data
.p2align 12
pagetable:
    .rept 64
    .8byte 0x0CF                # leaf petapage, PPN = 0, V R W X A D
    .endr
    .fill 448, 8, 0             # entry 64 is filled in at run time with a pointer to l3table
.p2align 12
l3table:
    .8byte 0
    .8byte 0x0CF                # entry 1: leaf terapage, PPN = 0
    .fill 510, 8, 0
.p2align 12
scratch:
    .fill 512, 8, 0
