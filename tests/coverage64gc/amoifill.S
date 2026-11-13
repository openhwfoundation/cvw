///////////////////////////////////////////
// amoifill.S
//
// Written: David_Harris@hmc.edu 9 November 2026
//
// Purpose: An uncached AMO (PBMT=NC page) while the I$ fills the next line.  The AMO's read and write and the
//          fill's beats share the bus through the EBU arbiter.  The AMO write's address phase once ignored
//          HREADY: the write was issued twice, and with a wait state on the fill (RAM_LATENCY > 0) the I$ line
//          got word 1 in place of word 0, so the first instruction of the line was skipped.  Each case empties
//          the I$, then runs the AMO at one of the 16 word slots of a line, so the fill of the next line starts
//          at a different cycle relative to the AMO.  Self-checking (WALLY-selfcheck.h); failure index
//          0x10 + slot: word 0 of the next line not executed, 0x30 + slot: word 1 not executed exactly once,
//          0x50 + slot: wrong AMO result, 0x70: wrong final memory value, 0xF0: an unexpected trap.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define PBMT_NC 0x2000000000000000

// address of the level-0 PTE that maps a label, into reg (clobbers t6)
.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x1FF
    slli \reg, \reg, 3
    la t6, l0table
    add \reg, \reg, t6
.endm

// One case: empty the I$, then an amoadd at word \slot of a line, followed by the first two words of the
// next line, which the I$ fills while the AMO is on the bus.  s0 = AMO address, s1 = 1, s2 = expected old value.
.macro AMOFILL slot
    fence.i                     # empty the I$, so the line holding the AMO and the line after it both miss
    li a3, 0
    li a4, 0
    j 2f
.p2align 6
2:
    .rept \slot
    nop
    .endr
    amoadd.d a5, s1, (s0)       # uncached AMO at word \slot
    .rept 15 - \slot
    nop
    .endr
    addi a3, a3, 1              # word 0 of the next line
    addi a4, a4, 1              # word 1 of the next line
    li t2, 1
    SC_CHECK_EQ a3, t2, 0x10 + \slot
    SC_CHECK_EQ a4, t2, 0x30 + \slot
    SC_CHECK_EQ a5, s2, 0x50 + \slot
    addi s2, s2, 1
.endm

.option norvc                   # 4-byte instructions, so each slot is one word of the line

main:
    SC_STRICT_TRAPS

    // Identity-map the first 2 MiB of RAM with 4 KiB pages (Sv39: root -> level 1 -> level 0),
    // built at run time so the AMO's page can be given PBMT=NC.
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

    L0_ENTRY nc_page, t0        # PBMT=NC on the AMO's page
    ld t1, 0(t0)
    li t6, PBMT_NC
    or t1, t1, t6
    sd t1, 0(t0)
    li t0, 0x4000000000000000   # menvcfg.PBMTE
    csrs menvcfg, t0
    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
    li a0, 1
    ecall                       # supervisor mode

    la s0, nc_page
    li s1, 1
    li s2, 0
    sd zero, 0(s0)
    AMOFILL 0
    AMOFILL 1
    AMOFILL 2
    AMOFILL 3
    AMOFILL 4
    AMOFILL 5
    AMOFILL 6
    AMOFILL 7
    AMOFILL 8
    AMOFILL 9
    AMOFILL 10
    AMOFILL 11
    AMOFILL 12
    AMOFILL 13
    AMOFILL 14
    AMOFILL 15
    ld a5, 0(s0)                # 16 increments
    li t2, 16
    SC_CHECK_EQ a5, t2, 0x70
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
    .fill 512, 8, 0
