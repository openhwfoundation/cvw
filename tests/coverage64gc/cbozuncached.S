///////////////////////////////////////////
// cbozuncached.S
//
// Written: David_Harris@hmc.edu 28 October 2026
//
// Purpose: Memory accesses immediately after an uncached cbo.zero (issue 2006).  cbo.zero to a PBMT=NC or IO
//          page writes the block over the bus without the D$.  The store or load right after it must still
//          reach the bus: a store must not be lost, and a load must not return the data of an earlier bus
//          read.  Self-checking (WALLY-selfcheck.h); failure index 1-2 NC page, 3-4 IO page, 0xF0 an
//          unexpected trap.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define PBMT_NC 0x2000000000000000
#define PBMT_IO 0x4000000000000000
#define OLD     0x4444444444444444  // in the block before each cbo.zero
#define NEW     0x9999999999999999  // stored right after cbo.zero

// address of the level-0 PTE that maps a label, into reg (clobbers t6)
.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x1FF
    slli \reg, \reg, 3
    la t6, l0table
    add \reg, \reg, t6
.endm

// set the PBMT of the identity-mapped page at label (clobbers t0, t1, t6)
.macro SET_PBMT label, pbmt
    L0_ENTRY \label, t0
    ld t1, 0(t0)
    li t6, \pbmt
    or t1, t1, t6
    sd t1, 0(t0)
.endm

// cbo.zero the block at label, then store right after it; then cbo.zero it again and load right after it,
// with a bus read of OLD just before so a dropped load would return OLD
.macro CASES label, index
    la s0, \label
    li s1, OLD
    sd s1, 0(s0)
    sd s1, 8(s0)
    ld t2, 8(s0)
    cbo.zero (s0)
    sd s2, 8(s0)                # store immediately after the uncached cbo.zero
    ld a2, 8(s0)
    SC_CHECK_EQ a2, s2, \index
    sd s1, 0(s0)
    ld t2, 0(s0)                # bus read of OLD
    cbo.zero (s0)
    ld a2, 0(s0)                # load immediately after the uncached cbo.zero
    SC_CHECK_EQ a2, zero, \index + 1
.endm

main:
    SC_STRICT_TRAPS

    // Identity-map the first 2 MiB of RAM with 4 KiB pages (Sv39: root -> level 1 -> level 0),
    // built at run time so individual pages can be given a PBMT.
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

    SET_PBMT nc_page, PBMT_NC
    SET_PBMT io_page, PBMT_IO
    li t0, 0x4000000000000080   # menvcfg.PBMTE, CBZE
    csrs menvcfg, t0
    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
    li a0, 1
    ecall                       # supervisor mode

    li s2, NEW
    CASES nc_page, 1
    CASES io_page, 3
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
io_page:
    .fill 512, 8, 0
