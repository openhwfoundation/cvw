///////////////////////////////////////////
// ramtop32.S
//
// Written: david_harris@hmc.edu 14 October 2026
//
// Purpose: On RV32 the uncore RAM array must back the whole 128 MiB region.  Before the ram_ahb
//          fix the array held RANGE/8 words of XLEN=32 bits (64 MiB - 4) and the address index
//          was 24 bits, so 0x84000000-0x87FFFFFF silently aliased 0x80000000-0x83FFFFFF and the
//          word at 0x83FFFFFC was out of the array.  The D$ hides the array until a writeback,
//          so force lines through with cbo.flush + cbo.inval.
//          Standalone RV32 init.
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

.section .text.main
main:
    li t5, 0x80100000         // victim in the lower 64 MiB
    li t6, 0xAAAA5555
    sw t6, 0(t5)
    cbo.flush (t5)            // write the victim line back to the RAM array
    cbo.inval (t5)

    li t3, 0x84100000         // same array index as the victim if the index wraps at 24 bits
    li t4, 0x33334444
    sw t4, 0(t3)
    cbo.flush (t3)
    cbo.inval (t3)

    lw t2, 0(t5)              // refill from RAM: the victim must be intact
    SC_CHECK_EQ t2, t6, 1
    lw t2, 0(t3)
    SC_CHECK_EQ t2, t4, 2

    li t5, 0x83FFFFC0         // top line of the first 64 MiB; its last word was out of the array
    li t6, 0x55556666
    sw t6, 60(t5)             // 0x83FFFFFC
    cbo.flush (t5)
    cbo.inval (t5)
    lw t2, 60(t5)
    SC_CHECK_EQ t2, t6, 3

    li t5, 0x87FFFFC0         // top line of the architected 128 MiB region
    li t6, 0x7777CCCC         // (positive: lw sign-extends)
    sw t6, 60(t5)             // 0x87FFFFFC
    cbo.flush (t5)
    cbo.inval (t5)
    lw t2, 60(t5)
    SC_CHECK_EQ t2, t6, 4

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
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
