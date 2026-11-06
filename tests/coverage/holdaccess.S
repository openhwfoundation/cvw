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
//          Self-checking (WALLY-selfcheck.h), with every check after the last page so the sequences
//          keep their timing: each held load writes its own register, each held store and cbo.zero
//          has its own word or line, and the data starts with a nonzero pattern, so the test checks
//          every loaded value, every stored word, and every line cbo.zero cleared.  The straddling
//          instruction is addi s2, s2, 1, so s2 counts the 18 straddles.  SC_STRICT_TRAPS fails the
//          test on any trap other than an ecall.  Failure indices: 1 straddle count, 2-3 warm-up
//          loads, 4-12 held loads, 13-16 cacheable stores, 20-50 the uncached lines, 0xF0 a trap.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"
.option norvc

#define COLD  0x5A5A0000            // word k of cold_lines holds COLD + k
#define NCPAT 0x3C3C0000            // word k of nc_page holds NCPAT + k

// CHECK_ZLINE off, word, index: the 64-byte line at nc_page + off was zeroed by cbo.zero and then took a
// store of word at offset 8, so its dwords are 0, word (zero-extended), 0, 0, 0, 0, 0, 0
.macro CHECK_ZLINE off, word, index
    .irp n, 0, 1, 2, 3, 4, 5, 6, 7
    ld t3, \off + 8*\n(a3)
    .if \n == 1
    li t2, \word
    .else
    li t2, 0
    .endif
    SC_CHECK_EQ t3, t2, \index + \n
    .endr
.endm

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
    SC_STRICT_TRAPS

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
    lw a7, 0(a2)
    la a3, nc_page
    lw a1, 0(a3)
    la a2, cold_lines
    addi a2, a2, 256            # cold lines the warm-up load did not touch
    addi a4, a3, 64             # nc_page lines 1 and 2, so each cbo.zero clears its own line
    addi a5, a3, 128
    li s2, 0                    # counts the straddling addi s2, s2, 1 instructions
    j page1

// Each page is exactly 4096 bytes and ends with the low half of an addi s2, s2, 1 (0x00190913)
// whose high half begins the next page, so the fetch straddles the page boundary.
.p2align 12
    .half 0x0000                # high half of the straddling addi from the previous page
page1:
    la t5, page2
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw s3, 0(a2)                # load that misses the data cache, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page2:
    la t5, page3
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw s3, 64(a2)               # store that misses the data cache, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page3:
    la t5, page4
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw s4, 128(a2)              # load that misses the data cache, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
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
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page5:
    la t5, page6
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw s5, 0(a3)                # uncached load, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page6:
    la t5, page7
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw s4, 8(a3)                # uncached store, 3 instructions before the straddle
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page7:
    la t5, page8
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw s6, 4(a2)                # load that misses the data cache, 2 instructions before the straddle
    nop
    nop
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page8:
    la t5, page9
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw s6, 68(a2)               # store that misses the data cache, 2 instructions before the straddle
    nop
    nop
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page9:
    la t5, page10
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw s7, 132(a2)              # load that misses the data cache, 2 instructions before the straddle
    nop
    nop
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page10:
    la t5, page11
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    cbo.zero (a4)               # cbo.zero to a non-cacheable page, performed on the bus, 2 instructions before the straddle
    nop
    nop
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page11:
    la t5, page12
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    lw s8, 64(a3)               # uncached load, 2 instructions before the straddle
    nop
    nop
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page12:
    la t5, page13
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1017
    nop
    .endr
    sw s7, 72(a3)               # uncached store, 2 instructions before the straddle
    nop
    nop
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page13:
    la t5, page14
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    lw s9, 8(a2)                # load that misses the data cache, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page14:
    la t5, page15
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    sw s9, 72(a2)               # store that misses the data cache, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page15:
    la t5, page16
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    lw s10, 136(a2)             # load that misses the data cache, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page16:
    la t5, page17
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    cbo.zero (a5)               # cbo.zero to a non-cacheable page, performed on the bus, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page17:
    la t5, page18
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    lw a6, 128(a3)              # uncached load, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019                # high half of the straddling addi from the previous page
page18:
    la t5, page19
    sfence.vma t5               # only the next code page leaves the TLBs; the data pages stay
    .rept 1016
    nop
    .endr
    sw s10, 136(a3)             # uncached store, 4 instructions before the straddle
    nop
    nop
    .half 0x0001
    .half 0x0001
    .half 0x0913                # low half of addi s2, s2, 1; its high half starts the next page
    .half 0x0019
page19:
    li a0, 3
    ecall

    // Every straddling addi ran exactly once
    li t2, 18
    SC_CHECK_EQ s2, t2, 1
    // Warm-up loads
    li t2, COLD + 0
    SC_CHECK_EQ a7, t2, 2
    li t2, NCPAT + 0
    SC_CHECK_EQ a1, t2, 3
    // Held cacheable loads: word k of cold_lines holds COLD + k, and a2 points at word 64
    li t2, COLD + 64
    SC_CHECK_EQ s3, t2, 4       # page 1: 0(a2)
    li t2, COLD + 96
    SC_CHECK_EQ s4, t2, 5       # page 3: 128(a2)
    li t2, COLD + 65
    SC_CHECK_EQ s6, t2, 6       # page 7: 4(a2)
    li t2, COLD + 97
    SC_CHECK_EQ s7, t2, 7       # page 9: 132(a2)
    li t2, COLD + 66
    SC_CHECK_EQ s9, t2, 8       # page 13: 8(a2)
    li t2, COLD + 98
    SC_CHECK_EQ s10, t2, 9      # page 15: 136(a2)
    // Held uncached loads, each from a line its page's cbo.zero had just cleared
    SC_CHECK_EQ s5, zero, 10    # page 5: 0(a3)
    SC_CHECK_EQ s8, zero, 11    # page 11: 64(a3)
    SC_CHECK_EQ a6, zero, 12    # page 17: 128(a3)
    // Held cacheable stores, one word each; the word after them is untouched
    lwu t3, 64(a2)
    li t2, COLD + 64
    SC_CHECK_EQ t3, t2, 13      # page 2
    lwu t3, 68(a2)
    li t2, COLD + 65
    SC_CHECK_EQ t3, t2, 14      # page 8
    lwu t3, 72(a2)
    li t2, COLD + 66
    SC_CHECK_EQ t3, t2, 15      # page 14
    lwu t3, 76(a2)
    li t2, COLD + 83
    SC_CHECK_EQ t3, t2, 16
    // Each uncached line was cleared by its cbo.zero and then took one held store at offset 8
    CHECK_ZLINE 0, COLD + 96, 20    # pages 4 and 6
    CHECK_ZLINE 64, COLD + 97, 30   # pages 10 and 12
    CHECK_ZLINE 128, COLD + 98, 40  # pages 16 and 18
    // The line after them still holds its pattern: no cbo.zero cleared more than one line
    ld t3, 192(a3)
    li t2, ((NCPAT + 49) << 32) | (NCPAT + 48)
    SC_CHECK_EQ t3, t2, 50

    SC_PASS
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
    .set k, 0
    .rept 1024
    .word NCPAT + k
    .set k, k + 1
    .endr
.p2align 6
cold_lines:
    .set k, 0
    .rept 1024
    .word COLD + k
    .set k, k + 1
    .endr
