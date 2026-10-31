///////////////////////////////////////////
// cbozwriteback.S
//
// Written: David_Harris@hmc.edu 27 October 2026 (RV32 port of tests/coverage64gc/cbozwriteback.S)
//
// Purpose: rv32gc coverage for cbo.zero on a dirty line.  When the line cbo.zero selects is dirty,
//          whether it is the hit way or the victim of a miss, cachefsm.sv writes it back first and then
//          zeros it when the bus acknowledges (STATE_WRITEBACK with CMOpM[3]: SetValid, SetDirty,
//          LRUWriteEn).  Four stores dirty every way of one set, then cbo.zero hits one of those lines
//          and misses on a fifth line that maps to the same set, so its victim is dirty too
//          (CMOZeroNoEviction with ~Hit & LineDirty).  The zeroed lines are read back and checked, and a
//          neighbouring word is checked to be untouched.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// rv32gc data cache: 4 ways of 4 KiB, 64-byte lines, so addresses 4 KiB apart share a set
#define WAYSIZE 4096

main:
    SC_STRICT_TRAPS
    la a0, lines
    li a1, WAYSIZE

    // Dirty every way of the set: a store to each of four lines 4 KiB apart
    li t0, 0x11111111
    sw t0, 0(a0)
    add a2, a0, a1
    li t0, 0x22222222
    sw t0, 0(a2)
    add a3, a2, a1
    li t0, 0x33333333
    sw t0, 0(a3)
    add a4, a3, a1
    li t0, 0x44444444
    sw t0, 0(a4)
    sw t0, 4(a4)                # a second word in the same line, for the untouched check below

    // cbo.zero that hits a dirty line: the cache writes the line back before zeroing it
    cbo.zero (a2)

    // cbo.zero that misses in a set whose ways are all dirty (cbo.zero leaves its line dirty), so the
    // victim must be written back first
    add a5, a4, a1
    cbo.zero (a5)

    // A cbo.zero whose line is clean, for contrast: clean the line, then zero it in place
    cbo.clean (a3)
    cbo.zero (a3)

    // The zeroed lines read back as zero and a dirty neighbour kept its data
    lw t1, 0(a2)
    SC_CHECK_EQ t1, zero, 1
    lw t1, 60(a2)
    SC_CHECK_EQ t1, zero, 2
    lw t1, 0(a5)
    SC_CHECK_EQ t1, zero, 3
    lw t1, 0(a3)
    SC_CHECK_EQ t1, zero, 4
    lw t1, 4(a4)
    li t2, 0x44444444
    SC_CHECK_EQ t1, t2, 5
    lw t1, 0(a0)
    li t2, 0x11111111
    SC_CHECK_EQ t1, t2, 6

    SC_PASS
    j done

.section .data
.p2align 12
lines:
    .fill 5*WAYSIZE, 1, 0x5A    # five lines 4 KiB apart map to the same set; nonzero so the zeroing shows
