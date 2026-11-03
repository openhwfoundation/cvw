///////////////////////////////////////////
// misalignedQuadSpill.S
//
// Written: David Harris david_harris@hmc.edu 30 October 2026
//
// Purpose: Misaligned flq and fsq that cross a D$ line must spill into two accesses (PR #1906).
//          Each access is checked against misaligned ld of the same bytes.  Passes trivially without Q.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2026 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"
main:
    csrr t0, misa
    srli t0, t0, 16             # misa.Q
    andi t0, t0, 1
    beqz t0, pass               # no Q: nothing to test
    li t0, 0x6000
    csrs mstatus, t0            # mstatus.FS = Dirty

    // Fill buf so that byte i holds i
    la s0, buf                  # 64-byte aligned, three lines
    li t2, 0                    # offset of the doubleword being built
    li t3, 192
1:  li t5, 0
    li t6, 0                    # byte within the doubleword
2:  add a2, t2, t6
    slli a1, t6, 3
    sll a2, a2, a1
    or t5, t5, a2
    addi t6, t6, 1
    li a3, 8
    blt t6, a3, 2b
    add t4, s0, t2
    sd t5, 0(t4)
    addi t2, t2, 8
    blt t2, t3, 1b

    // flq crossing the line boundary at buf+64; low and high halves checked against misaligned ld
    la s1, aligned
    .irp off, 49, 52, 56, 57, 60, 63
    flq ft0, \off(s0)
    fsq ft0, 0(s1)
    ld a4, 0(s1)
    ld a5, \off(s0)
    SC_CHECK_EQ a4, a5, \off
    ld a4, 8(s1)
    ld a5, \off+8(s0)
    SC_CHECK_EQ a4, a5, \off+100
    .endr

    // fsq crossing the line boundary at buf+128, read back with misaligned ld
    flq ft1, 16(s0)             # aligned source: bytes 16-31
    .irp off, 113, 116, 120, 121, 124, 127
    fsq ft1, \off(s0)
    ld a4, \off(s0)
    ld a5, 16(s0)
    SC_CHECK_EQ a4, a5, \off+200
    ld a4, \off+8(s0)
    ld a5, 24(s0)
    SC_CHECK_EQ a4, a5, \off+300
    .endr
pass:
    SC_PASS
    j done

.data
.align 6
buf: .fill 192, 1, 0
.align 4
aligned: .fill 16, 1, 0
