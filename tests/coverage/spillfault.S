///////////////////////////////////////////
// spillfault.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for a spilled instruction whose first halfword faults.  A 4-byte
//          instruction starts in the last halfword of a non-executable page (or a PMP grain
//          without execute permission) and ends in an executable one, so only the first half
//          faults and the IFU must report the fault it saved from the first half after the
//          second half fetches cleanly.  The IFU only treats a fetch as a spill when the bytes
//          it gets back look like a 32-bit instruction, so each straddling line is executed
//          once while it is still allowed, to bring it into the instruction cache, before the
//          permission is revoked.  Both traps resume after the straddling instruction.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
.option norvc

// address of the level-0 PTE that maps a label, into reg (clobbers t6)
.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x1FF
    slli \reg, \reg, 3
    la t6, l0table
    add \reg, \reg, t6
.endm

main:
    // Identity-map the first 2 MiB of RAM with 4 KiB pages (Sv39: root -> level 1 -> level 0),
    // built at run time so a single page can be marked non-executable.
    la t0, l0table
    li t1, 0x80000              # PPN of 0x80000000
    li t2, 512
build_l0:
    slli t3, t1, 10
    ori t3, t3, 0xCF            # V R W X A D
    sd t3, 0(t0)
    addi t0, t0, 8
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, build_l0
    la t0, l1table
    la t1, l0table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1               # non-leaf
    sd t1, 0(t0)                # level-1 entry 0: VA 0x80000000-0x801FFFFF
    la t0, roottable
    la t1, l1table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1
    sd t1, 16(t0)               # root entry 2: VA 0x80000000-0xBFFFFFFF

    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    // Warm-up pass: run through both straddling lines while they are still executable, so the
    // instruction cache holds them.  s2 = 0 makes the code after each straddle return.
    li s2, 0
    la t0, nx_page
    li t1, 0xFC0
    add t0, t0, t1
    jalr ra, t0, 0              # last line of nx_page, then the straddle into x_page
    la t0, nx_grain
    jalr ra, t0, 0              # the grain, then the straddle into x_grain

    li a0, 3
    ecall                       # machine mode to change the page table and the PMP

    // nx_page: readable but not executable
    L0_ENTRY nx_page, t0
    ld t1, 0(t0)
    li t2, -9                   # clear X (bit 3)
    and t1, t1, t2
    sd t1, 0(t0)
    sfence.vma

    // PMP: a 64-byte grain that is readable and writable but not executable, inside RWX memory
    la t0, nx_grain
    srli t0, t0, 2
    csrw pmpaddr0, t0           # TOR [0, nx_grain): RWX
    addi t0, t0, 16
    csrw pmpaddr1, t0           # TOR [nx_grain, nx_grain + 64): RW
    li t0, 0xFFFFFFFF
    csrw pmpaddr2, t0           # TOR [nx_grain + 64, 4 GiB): RWX
    li t0, 0x0F0B0F
    csrw pmpcfg0, t0

    li a0, 1
    ecall                       # supervisor mode: paging and PMP both apply
    li s2, 1                    # the code after each straddle now continues the test

    // Jump to the last halfword of the non-executable page.  The first half of the instruction
    // there page-faults; the second half, on x_page, does not.  The handler steps past the
    // straddling instruction to the branch at x_page + 2.
    la t0, nx_page
    li t1, 0xFFE
    add t0, t0, t1
    jalr zero, t0, 0
page_resume:

    // The same across the PMP grain: the first halfword is in the no-execute grain, the second is
    // in the RWX region after it.
    la t0, nx_grain
    addi t0, t0, 62
    jalr zero, t0, 0
pmp_resume:

    li a0, 3
    ecall
    j done

// The last 64 bytes of nx_page are real code so the warm-up pass can execute them: 15 nops, a
// c.nop, and the low half of an addi x0, x0, 0 whose high half is the first halfword of x_page.
.p2align 12
nx_page:
    .fill 4032, 1, 0
    .rept 15
    nop
    .endr
    .half 0x0001
    .half 0x0013
x_page:
    .half 0x0000
    bnez s2, page_resume
    ret

// The grain has the same shape: 15 nops, a c.nop, and the straddling addi into x_grain.
.p2align 6
nx_grain:
    .rept 15
    nop
    .endr
    .half 0x0001
    .half 0x0013
x_grain:
    .half 0x0000
    bnez s2, pmp_resume
    ret

.data
.p2align 12
roottable:
    .fill 512, 8, 0
l1table:
    .fill 512, 8, 0
l0table:
    .fill 512, 8, 0
