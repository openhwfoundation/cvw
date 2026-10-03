///////////////////////////////////////////
// cbozwriteback.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for cbo.zero on a dirty line.  When the line cbo.zero selects is dirty,
//          whether it is the hit way or the victim of a miss, cachefsm.sv writes it back first and
//          then zeros it when the bus acknowledges (STATE_WRITEBACK with CMOpM[3]).  Nothing else
//          in the suite zeroes a dirty line, so the writeback-then-zero path was unreached.  Four
//          stores dirty every way of one set, then cbo.zero hits one of those lines and misses on a
//          fifth line that maps to the same set, so its victim is dirty too.  The zeroed lines are
//          read back and checked, and a neighbouring line is checked to be untouched.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// rv64gc data cache: 4 ways of 4 KiB, 64-byte lines, so addresses 4 KiB apart share a set
#define WAYSIZE 4096

main:
    la a0, lines
    li a1, WAYSIZE

    // Dirty every way of the set: a store to each of four lines 4 KiB apart.  Each store misses
    // and fills a way, and the stored value marks the line as data rather than zeros.
    li t0, 0x1111111111111111
    sd t0, 0(a0)
    add a2, a0, a1
    li t0, 0x2222222222222222
    sd t0, 0(a2)
    add a3, a2, a1
    li t0, 0x3333333333333333
    sd t0, 0(a3)
    add a4, a3, a1
    li t0, 0x4444444444444444
    sd t0, 0(a4)
    sd t0, 8(a4)                # a second word in the same line, for the untouched check below

    // cbo.zero that hits a dirty line: the cache writes the line back before zeroing it
    cbo.zero (a2)

    // cbo.zero that misses in a set whose victim is dirty: all four ways are dirty (cbo.zero
    // leaves its line dirty), so the way chosen for the fifth line must be written back first
    add a5, a4, a1
    cbo.zero (a5)

    // A cbo.zero whose line is clean, for contrast: clean the line, then zero it in place
    cbo.clean (a3)
    cbo.zero (a3)

    // Check the zeroed lines read back as zero and that a dirty neighbour kept its data
    ld t1, 0(a2)
    SC_CHECK_EQ t1, zero, 1
    ld t1, 56(a2)
    SC_CHECK_EQ t1, zero, 2
    ld t1, 0(a5)
    SC_CHECK_EQ t1, zero, 3
    ld t1, 0(a3)
    SC_CHECK_EQ t1, zero, 4
    ld t1, 8(a4)
    li t2, 0x4444444444444444
    SC_CHECK_EQ t1, t2, 5
    ld t1, 0(a0)
    li t2, 0x1111111111111111
    SC_CHECK_EQ t1, t2, 6

    SC_PASS
    j done

.section .data
.p2align 12
lines:
    .fill 5*WAYSIZE, 1, 0       # five lines 4 KiB apart map to the same set, plus their neighbours
