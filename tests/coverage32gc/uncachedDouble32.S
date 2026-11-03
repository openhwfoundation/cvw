///////////////////////////////////////////
// uncachedDouble32.S
//
// Written: david_harris@hmc.edu 1 November 2026
//
// Purpose: On RV32 with D, an fld/fsd is wider than the 32-bit bus, so the PMA allows it only to cacheable memory.
//          fsd and fld to the CLINT's 64-bit mtimecmp raise store and load access faults, the fsd writes nothing,
//          and the fld leaves its destination unchanged.
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
    la t0, trap_log
    csrw mtvec, t0
    csrci mstatus, 8
    j main

.align 4
trap_log:                     // log mcause and mtval, then skip the 4-byte faulting instruction
    la t5, traps
    lw t6, 0(t5)
    addi t6, t6, 1
    sw t6, 0(t5)
    slli t6, t6, 3
    add t5, t5, t6
    csrr t6, mcause
    sw t6, -4(t5)
    csrr t6, mtval
    sw t6, 0(t5)
    csrr t6, mepc
    addi t6, t6, 4
    csrw mepc, t6
    mret

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

.option norvc
.section .text.main
main:
    li t0, 0x2000
    csrs mstatus, t0          // mstatus.FS = Initial
    li a0, MTIMECMP
    la a1, dsrc
    la a2, dresult
    li t0, -1
    sw t0, 0(a0)              // mtimecmp = all ones
    sw t0, 4(a0)
    fld ft0, 0(a1)
    fld ft1, 8(a1)
    fsd ft0, 0(a0)            // store access fault
    fld ft1, 0(a0)            // load access fault
    lw s0, 0(a0)
    lw s1, 4(a0)
    fsd ft1, 0(a2)
    lw s2, 0(a2)
    lw s3, 4(a2)

    li t2, -1
    SC_CHECK_EQ s0, t2, 1     // the fsd wrote nothing
    SC_CHECK_EQ s1, t2, 2
    li t2, HI
    SC_CHECK_EQ s2, t2, 3     // the fld left ft1 unchanged
    li t2, LO
    SC_CHECK_EQ s3, t2, 4
    la a3, traps
    lw t3, 0(a3)
    li t2, 2
    SC_CHECK_EQ t3, t2, 5     // both trapped
    lw t3, 4(a3)
    li t2, 7
    SC_CHECK_EQ t3, t2, 6     // store access fault
    lw t3, 8(a3)
    SC_CHECK_EQ t3, a0, 7
    lw t3, 12(a3)
    li t2, 5
    SC_CHECK_EQ t3, t2, 8     // load access fault
    lw t3, 16(a3)
    SC_CHECK_EQ t3, a0, 9

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
    .word HI, LO
dresult:
    .word 0, 0
traps:                        // number of traps, then mcause and mtval of each
    .fill 5, 4, 0
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
