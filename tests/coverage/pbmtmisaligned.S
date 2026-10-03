///////////////////////////////////////////
// pbmtmisaligned.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for accesses through Svpbmt non-cacheable (NC) pages: misaligned loads,
//          stores and AMOs to an NC data page, and instruction fetch from an NC code page while
//          the ITLB misses and the pipeline is stalled by data cache misses and stores.
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

    // PBMT = NC (bit 61) on the data page and the code page
    li t2, 0x2000000000000000
    L0_ENTRY nc_data, t0
    ld t1, 0(t0)
    or t1, t1, t2
    sd t1, 0(t0)
    L0_ENTRY nc_code, t0
    ld t1, 0(t0)
    or t1, t1, t2
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

    // Misaligned accesses through the NC page, each after an sfence.vma so the DTLB misses while
    // the access is outstanding.  The page is idempotent but not cacheable, so misaligned loads and
    // stores are not handled in hardware and raise address-misaligned exceptions; misaligned AMOs
    // raise access faults.  The handler skips them all.
    la a1, nc_data
    sfence.vma
    lw t1, 1(a1)
    sfence.vma
    lh t1, 1(a1)
    sfence.vma
    sw t1, 1(a1)
    sfence.vma
    sd t1, 2(a1)
    sfence.vma
    ld t1, 4(a1)
    addi a2, a1, 2
    sfence.vma
    amoadd.w t1, zero, (a2)     # misaligned AMOs to the NC page take an access fault
    sfence.vma
    amoadd.d t1, zero, (a2)
    sfence.vma
    amoswap.w t1, zero, (a2)
    lw t1, 0(a1)                # aligned accesses to the same page
    sw t1, 0(a1)
    amoadd.w t1, zero, (a1)

    // Execute from the NC page after an sfence.vma, so the ITLB misses on a non-cacheable page and
    // every instruction fetch there goes uncached to the bus.
    sfence.vma
    la t0, nc_code
    jalr ra, t0, 0

    li a0, 3
    ecall
    j done

// Runs from the non-cacheable page.  The data cache misses stall the pipeline while the uncached
// fetch of the following instruction is in flight, and each store makes the RAM insert a wait
// state on the read that follows it.
.p2align 12
nc_code:
    la t0, cold_data
    lw t1, 0(t0)
    sw t1, 64(t0)
    lw t1, 128(t0)
    sw t1, 192(t0)
    lw t1, 256(t0)
    sw t1, 320(t0)
    lw t1, 384(t0)
    sw t1, 448(t0)
    sw t1, 512(t0)
    sw t1, 576(t0)
    lw t1, 640(t0)
    ret
.p2align 12

.data
.p2align 12
roottable:
    .fill 512, 8, 0
l1table:
    .fill 512, 8, 0
l0table:
    .fill 512, 8, 0
nc_data:
    .fill 512, 8, 0
cold_data:
    .fill 512, 8, 0
