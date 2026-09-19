///////////////////////////////////////////
// holdaccess.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for a memory access that completes while the pipeline is stalled by an
//          ITLB miss that arrived after the access started.  The walker pre-empts an access that
//          has not started, so an ITLB miss present when a load enters the Memory stage simply
//          wins; the held-access path needs the miss to appear once the access is committed.  A
//          32-bit instruction straddling the page boundary does that: its first half is fetched
//          normally and its second half, on the next page, is translated a cycle later, after the
//          data access has left the cache's idle state.  Each page here ends with a load, store or
//          cbo.zero that misses the data cache or goes uncached, followed by a straddling addi
//          whose second half is on a page that has just been flushed from the TLB.  The access
//          finishes while the fetch waits for the walker, and the LSU must hold the finished
//          access until it retires instead of reissuing it.
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
    // built at run time so one page can be marked non-cacheable.
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

    // PBMT = NC (bit 61) on nc_page
    L0_ENTRY nc_page, t0
    ld t1, 0(t0)
    li t2, 0x2000000000000000
    or t1, t1, t2
    sd t1, 0(t0)
    li t0, 0x40000000000000F0   # menvcfg.PBMTE, and CBZE/CBCFE/CBIE so supervisor mode may use cbo.zero
    csrs menvcfg, t0

    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    // Bring the data pages into the DTLB, so the accesses below miss only in the cache, not the TLB.
    la a2, cold_lines
    lw t1, 0(a2)
    la a3, nc_page
    lw t1, 0(a3)
    la a2, cold_lines
    addi a2, a2, 256            # cold lines the warm-up load did not touch
    j page1

// Each page is exactly 4096 bytes and ends with the low half of an addi x0, x0, 0 whose high
// half begins the next page, so the fetch straddles the page boundary.
.p2align 12
    .half 0x0000                # high half of the straddling addi from the previous page
page1:
    la t5, page2
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw t1, 0(a2)                # load that misses the data cache, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page2:
    la t5, page3
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw t1, 64(a2)               # store that misses the data cache, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page3:
    la t5, page4
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw t1, 128(a2)              # load that misses the data cache, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page4:
    la t5, page5
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    cbo.zero (a3)               # cbo.zero to a non-cacheable page, performed on the bus, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page5:
    la t5, page6
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw t1, 0(a3)                # uncached load, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page6:
    la t5, page7
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw t1, 8(a3)                # uncached store, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page7:
    la t5, page8
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw t1, 0(a2)                # load that misses the data cache, 2 instructions before the straddle
    nop
    nop
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page8:
    la t5, page9
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw t1, 64(a2)               # store that misses the data cache, 2 instructions before the straddle
    nop
    nop
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page9:
    la t5, page10
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw t1, 128(a2)              # load that misses the data cache, 2 instructions before the straddle
    nop
    nop
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page10:
    la t5, page11
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    cbo.zero (a3)               # cbo.zero to a non-cacheable page, performed on the bus, 2 instructions before the straddle
    nop
    nop
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page11:
    la t5, page12
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw t1, 0(a3)                # uncached load, 2 instructions before the straddle
    nop
    nop
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page12:
    la t5, page13
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw t1, 8(a3)                # uncached store, 2 instructions before the straddle
    nop
    nop
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page13:
    la t5, page14
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    lw t1, 0(a2)                # load that misses the data cache, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page14:
    la t5, page15
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    sw t1, 64(a2)               # store that misses the data cache, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page15:
    la t5, page16
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    lw t1, 128(a2)              # load that misses the data cache, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page16:
    la t5, page17
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    cbo.zero (a3)               # cbo.zero to a non-cacheable page, performed on the bus, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page17:
    la t5, page18
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    lw t1, 0(a3)                # uncached load, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000                # high half of the straddling addi from the previous page
page18:
    la t5, page19
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    sw t1, 8(a3)                # uncached store, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0013                # low half of addi x0, x0, 0; its high half starts the next page
    .half 0x0000
page19:
    li a0, 3
    ecall
    j done

.data
.p2align 12
roottable:
    .fill 512, 8, 0
l1table:
    .fill 512, 8, 0
l0table:
    .fill 512, 8, 0
nc_page:
    .fill 512, 8, 0
.p2align 6
cold_lines:
    .fill 512, 8, 0
