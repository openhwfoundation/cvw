///////////////////////////////////////////
// cbompbmt.S
//
// Written: David_Harris@hmc.edu 28 October 2026
//
// Purpose: Cache-block management instructions through Svpbmt NC and IO aliases of a cacheable page
//          (issue 2003).  Each case dirties a D$ line through the cacheable identity mapping, issues
//          cbo.clean, cbo.flush or cbo.inval through an NC or IO alias of the same physical page, and
//          reads memory back through the alias.  CMOs ignore cacheability, so the D$ must write the
//          line back and the uncached load must return the store.  menvcfg.CBIE = 01 makes cbo.inval
//          perform a flush, so every case has one architectural result.
//          Self-checking (WALLY-selfcheck.h); failure index = case number 1-6, 0xF0 an unexpected trap.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define PBMT_NC 0x2000000000000000
#define PBMT_IO 0x4000000000000000

// address of the level-0 PTE that maps a label, into reg (clobbers t6)
.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x1FF
    slli \reg, \reg, 3
    la t6, l0table
    add \reg, \reg, t6
.endm

// map the page at label alias to the physical page cbo_data with the given PBMT (clobbers t0, t1, t6)
.macro ALIAS alias, pbmt
    L0_ENTRY \alias, t0
    la t1, cbo_data
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 0xC7            # V R W A D
    li t6, \pbmt
    or t1, t1, t6
    sd t1, 0(t0)
.endm

// dirty the line through the cacheable mapping, run op through alias, and read memory through alias
.macro CASE op, alias, index
    addi s1, s1, 1
    sd s1, 0(s0)                # dirty the D$ line through the cacheable mapping
    fence iorw, iorw
    la a1, \alias
    \op (a1)
    fence iorw, iorw
    ld a2, 0(a1)                # uncached read of memory
    SC_CHECK_EQ a2, s1, \index
.endm

main:
    SC_STRICT_TRAPS

    // Identity-map the first 2 MiB of RAM with 4 KiB pages (Sv39: root -> level 1 -> level 0),
    // built at run time so individual pages can be remapped.
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

    // nc_alias and io_alias map cbo_data with PBMT = NC and IO
    ALIAS nc_alias, PBMT_NC
    ALIAS io_alias, PBMT_IO
    li t0, 0x4000000000000050   # menvcfg.PBMTE, CBCFE = 1, CBIE = 01 (cbo.inval flushes)
    csrs menvcfg, t0
    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
    li a0, 1
    ecall                       # supervisor mode

    la s0, cbo_data
    li s1, 0x1111111111111100
    CASE cbo.clean, nc_alias, 1
    CASE cbo.flush, nc_alias, 2
    CASE cbo.inval, nc_alias, 3
    CASE cbo.clean, io_alias, 4
    CASE cbo.flush, io_alias, 5
    CASE cbo.inval, io_alias, 6
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
cbo_data:
    .fill 512, 8, 0
nc_alias:                       # remapped to cbo_data; never accessed at its own physical address
    .fill 512, 8, 0
io_alias:
    .fill 512, 8, 0
