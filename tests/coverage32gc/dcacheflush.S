///////////////////////////////////////////
// dcacheflush.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: rv32gc D$ coverage for CMO valid-bit clears in every way and for the fence.i D$ flush
//          ending on a dirty line.
//          1. (RV32 port of the flush part of tests/coverage64gc/dcache1.S) Four lines that share a set
//             fill the four ways; cbo.flush of dirty lines, cbo.flush of clean lines and cbo.inval
//             clear the valid bit of each way (cacheway.sv ClearValidWay / ValidBits clear, cachefsm.sv
//             ClearValid in STATE_ACCESS and STATE_WRITEBACK).  Reloading each line reads memory, so the
//             writebacks are checked.
//          2. fence.i flushes the D$ (STATE_FLUSH / STATE_FLUSH_WRITEBACK).  The flush visits the sets
//             in order and the ways 0 to 3 within a set, so it ends (FlushFlag) on set 63, way 3.  Making
//             every way of set 63 dirty makes the last line dirty: STATE_FLUSH sees LineDirty with
//             FlushFlag and STATE_FLUSH_WRITEBACK gets CacheBusAck with FlushFlag (cachefsm.sv L135-L139,
//             FlushCntRst).  cbo.inval then discards the cached copies and reloads check memory.
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

// rv32gc D$: 4 ways of 4 KiB, 64-byte lines: addresses 4 KiB apart share a set
#define WAYSIZE 4096

main:
    SC_STRICT_TRAPS
    la s0, lines                // s0 = lines (set 0 of a 4 KiB page)
    li s1, WAYSIZE

    // 1. Fill the four ways of set 0 with dirty lines: line n (address s0 + n*4 KiB) holds 0x1000*n + 0x11
    mv t2, s0
    li t3, 0x11
    li t4, 4
1:  sw t3, 0(t2)
    sw t3, 4(t2)
    add t2, t2, s1
    add t3, t3, s1
    addi t4, t4, -1
    bnez t4, 1b
    // cbo.flush of each dirty line: written back, then invalidated (ClearValid in STATE_WRITEBACK)
    mv t2, s0
    li t4, 4
2:  cbo.flush (t2)
    add t2, t2, s1
    addi t4, t4, -1
    bnez t4, 2b
    // reload: each line is fetched again from memory and holds its value
    mv a1, s0
    li a2, 0x11
    li a3, 4
3:  lw a0, 0(a1)
    SC_CHECK_EQ_ADR a0, a2, a1, 1
    add a1, a1, s1
    add a2, a2, s1
    addi a3, a3, -1
    bnez a3, 3b
    // the four lines are now clean and valid: cbo.flush of a clean line just invalidates it (ClearValid in
    // STATE_ACCESS with CMOpM[2] & ~HitLineDirty)
    mv t2, s0
    li t4, 4
4:  cbo.flush (t2)
    add t2, t2, s1
    addi t4, t4, -1
    bnez t4, 4b
    // reload them (clean), then cbo.inval invalidates each (ClearValid in STATE_ACCESS with CMOpM[0]).
    // The lines are clean because whether cbo.inval discards dirty data is implementation-defined.
    mv t2, s0
    li t4, 4
5:  lw t3, 0(t2)
    add t2, t2, s1
    addi t4, t4, -1
    bnez t4, 5b
    mv t2, s0
    li t4, 4
6:  cbo.inval (t2)
    add t2, t2, s1
    addi t4, t4, -1
    bnez t4, 6b
    // word 1 of each line is fetched from memory again
    mv a1, s0
    li a2, 0x11
    li a3, 4
7:  lw a0, 4(a1)
    SC_CHECK_EQ_ADR a0, a2, a1, 2
    add a1, a1, s1
    add a2, a2, s1
    addi a3, a3, -1
    bnez a3, 7b

    // 2. Dirty every way of set 63 (offset 0xFC0 in each page), with line n holding 0x2000*n + 0x22, then
    //    fence.i flushes the D$ and its last line (set 63, way 3) is dirty
    li s2, 0xFC0
    add s2, s2, s0              // s2 = set 63 of the first page
    mv t2, s2
    li t3, 0x22
    li t4, 4
8:  sw t3, 0(t2)
    add t2, t2, s1
    add t3, t3, s1
    add t3, t3, s1
    addi t4, t4, -1
    bnez t4, 8b
    fence.i
    // the flush wrote every line back; cbo.inval discards the cached copies, so the reloads read memory
    mv t2, s2
    li t4, 4
9:  cbo.inval (t2)
    add t2, t2, s1
    addi t4, t4, -1
    bnez t4, 9b
    mv a1, s2
    li a2, 0x22
    li a3, 4
10: lw a0, 0(a1)
    SC_CHECK_EQ_ADR a0, a2, a1, 3
    add a1, a1, s1
    add a2, a2, s1
    add a2, a2, s1
    addi a3, a3, -1
    bnez a3, 10b

    SC_PASS
    j done

.data
.align 12
lines:
    .fill 4*WAYSIZE, 1, 0
