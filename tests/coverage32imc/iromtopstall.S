///////////////////////////////////////////
// iromtopstall.S
//
// Written: david_harris@hmc.edu 6 November 2026
//
// Purpose: rv32imc stalls and flushes during a spill.  The IROM returns a 32-bit instruction whole from
//          any halfword, so the only IROM fetch that spills is a 32-bit instruction in the last halfword
//          of the IROM, whose second half at 0x80800000 takes an instruction access fault (as in
//          iromtopspill.S).  The last 12 bytes of the IROM hold
//              0x807FFFF4  sw    s0, 0(a3)
//              0x807FFFF8  divu  s1, s3, s4    stalls in Execute for many cycles
//              0x807FFFFC  c.add s2, s1        uses the quotient
//              0x807FFFFE  0x0013              lower half of addi x0, x0, 0
//          so when the spill is detected (fetch of 0x807FFFFE) the store is in Memory, the divide in Execute
//          and the add in Decode.
//          1. With a3 in the DTIM, the spill stall holds the store in Memory with the DTIM disabled, and
//             the divide stall continues into the second fetch of the spill, which waits for it.
//          2. With a3 = 0 (nothing there), the store takes an access fault in Memory, so the trap flushes
//             the pipeline in the cycle the spill is detected.
//          Placement as in iromtopspill.S: the code is in .text.init; .text.main is 4 MiB aligned and
//          pads to the last 12 bytes of the IROM.  The image is 8 MiB (18 MB memfile).
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

// SC_CHECK_EQ actual, expected, index: as in iromtopspill.S
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

// RUNTOP: run the last 12 bytes of the IROM; the trap returns to ra, after the jump
.macro RUNTOP
    li s9, 0
    li s10, 0
    li s11, 0
    la t0, topfault
    csrw mtvec, t0
    la t1, irom_top_seq
    jalr ra, t1
    la t0, trap_handler
    csrw mtvec, t0
.endm

.section .text.init
main:
    la t0, irom_top                     // check that the alignment and padding put irom_top at the IROM top
    li t1, IROM_TOP
    SC_CHECK_EQ t0, t1, 1

    // 1. The store and the divide stall during the spill
    li s0, 0x12345678                   // stored
    la a3, storebuf
    li s3, 1000
    li s4, 7
    li s2, 100
    RUNTOP
    li t2, 1
    SC_CHECK_EQ s9, t2, 2               // exactly one trap
    SC_CHECK_EQ s10, t2, 3              // mcause = instruction access fault
    li t2, IROM_TOP + 2
    SC_CHECK_EQ s11, t2, 4              // mtval = the faulting second half
    lw t3, 0(a3)
    SC_CHECK_EQ t3, s0, 5               // the store was written once the stall ended
    li t2, 100 + 1000/7
    SC_CHECK_EQ s2, t2, 6               // the add used the quotient

    // 2. The store faults while the spill is detected
    li a3, 0                            // no memory or peripheral at 0
    li s2, 100
    RUNTOP
    li t2, 1
    SC_CHECK_EQ s9, t2, 7               // exactly one trap
    li t2, 7
    SC_CHECK_EQ s10, t2, 8              // mcause = store access fault
    SC_CHECK_EQ s11, zero, 9            // mtval = the store address
    li t2, 100
    SC_CHECK_EQ s2, t2, 10              // the divide and add after the store were flushed

    la t0, selfcheck_record             // SC_PASS
    li t1, 1
    sw t1, 0(t0)
    j done

.align 4
topfault:
    csrr s10, mcause
    csrr s11, mtval
    addi s9, s9, 1
    csrw mepc, ra
    mret

.section .text.main
    .balign IROM_HALF                   // the 4 MiB boundary in the middle of the IROM
irom_mid:
    .skip IROM_HALF - 12                // to the last 12 bytes of the IROM
irom_top_seq:
.option push
.option norvc
    sw s0, 0(a3)                        // in Memory when the spill is detected
    divu s1, s3, s4                     // in Execute
.option pop
    c.add s2, s1                        // in Decode, waiting for the quotient
irom_top:
    .2byte 0x0013                       // lower half of addi x0, x0, 0; the upper half would be at 0x80800000

.section .data
.align 3
storebuf:
    .word 0
    .word 0, 0                          // as in WALLY-selfcheck.h
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
