///////////////////////////////////////////
// iromtopcompressed.S
//
// Written: david_harris@hmc.edu 6 November 2026
//
// Purpose: rv32imc compressed instruction in the last halfword of the IROM.  The IROM returns a 32-bit
//          instruction whole from any halfword, so only an instruction in the last halfword of the IROM
//          could spill; a compressed one there does not, and it runs without a fault
//          (iromtopspill.S has a 32-bit one there).
//          Placement as in iromtopspill.S.  The image is 8 MiB (18 MB memfile).
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

.section .text.init
main:
    la t0, irom_top                     // check that the alignment and padding put irom_top at the IROM top
    li t1, IROM_TOP
    SC_CHECK_EQ t0, t1, 1

    li s9, 0
    la t0, topfault                     // no trap is expected; count any
    csrw mtvec, t0
    li s2, 0
    la t1, irom_top_seq
    jalr ra, t1                         // returns from the last halfword
    la t0, trap_handler
    csrw mtvec, t0
    SC_CHECK_EQ s9, zero, 2             // no trap
    li t2, 5
    SC_CHECK_EQ s2, t2, 3               // both instructions ran

    la t0, selfcheck_record             // SC_PASS
    li t1, 1
    sw t1, 0(t0)
    j done

.align 4
topfault:
    addi s9, s9, 1
    csrw mepc, ra
    mret

.section .text.main
    .balign IROM_HALF                   // the 4 MiB boundary in the middle of the IROM
irom_mid:
    .skip IROM_HALF - 4                 // to the last 4 bytes of the IROM
irom_top_seq:
    c.addi s2, 5
irom_top:
    c.jr ra                             // in the last halfword of the IROM

.section .data
.align 3
    .word 0, 0                          // as in WALLY-selfcheck.h
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
