///////////////////////////////////////////
// uncachedDouble32.S
//
// Written: david_harris@hmc.edu 1 November 2026
//
// Purpose: On RV32 with D, an uncached fld/fsd is wider than the 32-bit bus and is performed as two beats.
//          fsd and fld to the CLINT's 64-bit mtimecmp must move both words, and a narrower load that follows
//          must see only its own word.  Before the split, the access went out as one 32-bit transfer.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

.section .text.init
.global rvtest_entry_point
rvtest_entry_point:
    la t0, trap_fail
    csrw mtvec, t0
    csrci mstatus, 8
    j main

.align 4
trap_fail:                    // no trap is expected; report failure 0xF0
    la t0, selfcheck_record
    li t1, 2
    sw t1, 0(t0)
    li t1, 0xF0
    sw t1, 4(t0)
    csrr t1, mcause
    sw t1, 8(t0)
    la t0, tohost
    li t1, (2 << 1) | 1
    sw t1, 0(t0)
done:
    la t1, tohost
    li t0, 1
    sw t0, 0(t1)
self_loop:
    j self_loop

.macro SC_CHECK_EQ actual, expected, index
    beq \actual, \expected, 9f
    la t0, selfcheck_record
    li t1, 2
    sw t1, 0(t0)
    li t1, \index
    sw t1, 4(t0)
    sw \expected, 12(t0)
    sw \actual, 16(t0)
    la t0, tohost
    li t1, (2 << 1) | 1
    sw t1, 0(t0)
    j self_loop
9:
.endm

.equ MTIMECMP, 0x02004000
.equ LO, 0x01234567
.equ HI, 0x89ABCDEF

.section .text.main
main:
    li t0, 0x2000
    csrs mstatus, t0          // mstatus.FS = Initial
    li a0, MTIMECMP
    la a1, dsrc
    la a2, dresult
    fld ft0, 0(a1)
    fsd ft0, 0(a0)            // uncached fsd: two 32-bit beats
    lw s0, 0(a0)
    lw s1, 4(a0)
    fld ft1, 0(a0)            // uncached fld: two 32-bit beats
    fsd ft1, 0(a2)
    lw s2, 0(a2)
    lw s3, 4(a2)
    lw s4, 4(a0)              // a narrow load after the wide one sees only its own word
    li t0, -1
    sw t0, 0(a0)              // put mtimecmp back out of reach
    sw t0, 4(a0)

    li t2, LO
    li t3, HI
    SC_CHECK_EQ s0, t2, 1     // both words written
    SC_CHECK_EQ s1, t3, 2
    SC_CHECK_EQ s2, t2, 3     // both words read
    SC_CHECK_EQ s3, t3, 4
    SC_CHECK_EQ s4, t3, 5

    la t0, selfcheck_record
    li t1, 1
    sw t1, 0(t0)
    j done

.section .tohost
tohost:
    .word 0
    .word 0
fromhost:
    .word 0
    .word 0

.section .data
.align 3
dsrc:
    .word LO, HI
dresult:
    .word 0, 0
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
