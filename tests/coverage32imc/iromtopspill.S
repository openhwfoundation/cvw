///////////////////////////////////////////
// iromtopspill.S
//
// Written: david_harris@hmc.edu 27 October 2026
//
// Purpose: rv32imc instruction access fault on the second half of a spilled fetch.
//          rv32imc fetches only from the IROM (0x80000000-0x807FFFFF); nothing on the bus is executable,
//          so the IFU fetch buffer is never written and a faulting fetch always delivers 0x0000, an
//          illegal compressed instruction.  The one way to fetch a legal instruction that takes an
//          instruction access fault is a 32-bit instruction whose first half is the last halfword of
//          the IROM: the spill fetches the second half from 0x80800000, which faults, and merges the
//          zero upper half with the IROM's lower half.  Lower half 0x0013 makes the merged instruction
//          addi x0, x0, 0, so the access fault is the only exception.  mtval reports the faulting half.
//
//          Placement: the test code lives in .text.init, next to the library code, and .text.main holds
//          only the pad.  .balign 4 MiB gives .text.main 4 MiB alignment, so irom_mid is the only 4 MiB
//          boundary inside the IROM above the rest of the image (IROM base + 4 MiB); padding 4 MiB - 2
//          from that label reaches the last IROM halfword.  No .text.main address is assumed, and the
//          address is checked at run time.  WALLY-selfcheck.h is not included because its handler in
//          .text.main jumps to done in .text.init, which is out of jal range once .text.main is 4 MiB
//          aligned; the self-check macro below follows it.  The image is 8 MiB (18 MB memfile).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

.option norelax

#include "WALLY-init-lib.h"

#define IROM_HALF 0x400000              // half the 8 MiB IROM (IROM_RANGE + 1 = 0x800000)
#define IROM_TOP  0x807FFFFE            // last halfword of the IROM (IROM_BASE + IROM_RANGE - 1)

// SC_CHECK_EQ actual, expected, index: as in WALLY-selfcheck.h; on a mismatch record status 2 with the
// index, expected and actual values in selfcheck_record and report failure (tohost = 5)
.macro SC_CHECK_EQ actual, expected, index
    beq \actual, \expected, 9f
    la t0, selfcheck_record
    li t1, 2
    sw t1, 0(t0)
    li t1, \index
    sw t1, 4(t0)
    sw zero, 8(t0)
    sw \expected, 12(t0)
    sw \actual, 16(t0)
    la t0, tohost
    li t1, (2 << 1) | 1
    sw t1, 0(t0)
    j done
9:
.endm

.section .text.init
main:
    la t0, irom_top                     // check that the alignment and padding put irom_top at the IROM top
    li t1, IROM_TOP
    SC_CHECK_EQ t0, t1, 1

    li s9, 0
    li s10, 0
    li s11, 0
    la t0, spillfault                   // the fault returns to ra, after the jump that faulted
    csrw mtvec, t0
    la t1, irom_top
    jalr ra, t1
    la t0, trap_handler
    csrw mtvec, t0

    li t2, 1
    SC_CHECK_EQ s9, t2, 2               // exactly one trap
    SC_CHECK_EQ s10, t2, 3              // mcause = instruction access fault
    li t2, IROM_TOP + 2
    SC_CHECK_EQ s11, t2, 4              // mtval = the faulting second half

    la t0, selfcheck_record             // SC_PASS
    li t1, 1
    sw t1, 0(t0)
    j done

.align 4
spillfault:
    csrr s10, mcause
    csrr s11, mtval
    addi s9, s9, 1
    csrw mepc, ra
    mret

.section .text.main
    .balign IROM_HALF                   // the 4 MiB boundary in the middle of the IROM
irom_mid:
    .skip IROM_HALF - 2                 // to the last halfword of the IROM
irom_top:
    .2byte 0x0013                       // lower half of addi x0, x0, 0; the upper half would be at 0x80800000

.section .data
.align 3
    .word 0, 0                          // as in WALLY-selfcheck.h
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
