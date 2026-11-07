///////////////////////////////////////////
// dcachestorestall.S
//
// Written: David_Harris@hmc.edu 7 November 2026
//
// Purpose: A store that hits the D$ sets its way's dirty bit (SelectedWriteWordEn) while the whole pipeline is
//          stalled by an I$ miss, so the data array sees a write enable with CacheEn = 0, in every way.  Four
//          lines 4 KiB apart fill one set (one per way), and each is stored to while a fetch from a line that
//          has never been fetched misses: the store sits two or three instructions before the end of an I$ line,
//          so it is in Memory when the next line's fetch stalls the pipeline.  Passes if it runs to completion.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"

// Store to \reg at the given byte offset in a fresh 64-byte I$ line, followed by nops to the end of the line
.macro STORE_BEFORE_MISS reg, offset
    .align 6
    .rept \offset / 4
    nop
    .endr
    sw x0, 0(\reg)
    .rept (60 - \offset) / 4
    nop
    .endr
.endm

main:
.option push
.option norvc
    la s1, buf
    li t0, 4096
    add s2, s1, t0
    add s3, s2, t0
    add s4, s3, t0
    lw t1, 0(s1)            # fill the set: one line in each way
    lw t1, 0(s2)
    lw t1, 0(s3)
    lw t1, 0(s4)
    .irp reg, s1, s2, s3, s4
    STORE_BEFORE_MISS \reg, 52
    STORE_BEFORE_MISS \reg, 56
    .endr
.option pop
    j done

.data
.align 12
buf:
    .space 16384
