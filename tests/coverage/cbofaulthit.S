///////////////////////////////////////////
// cbofaulthit.S
//
// Written: David_Harris@hmc.edu 3 October 2026
//
// Purpose: Test coverage for a cbo.inval that hits in the data cache but takes an access fault.
//          The hit asks the way to clear its valid bit, and the trap flushes the Writeback
//          stage in the same cycle, which must cancel the clear.  Four lines that share a set
//          are loaded first, so the faulting cbo.invals hit in each of the four ways.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"

main:
    li t0, 0xF0             # menvcfg.CBZE, CBCFE and CBIE, so supervisor mode may use cbo.inval
    csrw menvcfg, t0

    // Load four lines 4 KiB apart: they share a set, so they fill all four ways
    la s0, lines
    li s1, 4096
    mv t0, s0
    li t1, 4
fill:
    ld t2, 0(t0)
    add t0, t0, s1
    addi t1, t1, -1
    bnez t1, fill

    // PMP region 0 denies all access to the four lines (16 KiB NAPOT); region 2 allows everything else
    srli t0, s0, 2
    ori t0, t0, 0x7FF
    csrw pmpaddr0, t0
    csrw pmpaddr1, zero
    li t0, 0xFFFFFFFF
    csrw pmpaddr2, t0
    li t0, 0x0F0018         # region 0 NAPOT no access, region 1 off, region 2 TOR RWX
    csrw pmpcfg0, t0

    li a0, 1                # supervisor mode, so the PMP applies
    ecall

    // a cbo.inval needs read or write permission, so each takes a store/AMO access fault
    mv t0, s0
    li t1, 4
inval:
    cbo.inval (t0)
    add t0, t0, s1
    addi t1, t1, -1
    bnez t1, inval

    li a0, 3                # back to machine mode
    ecall
    j done

.data
.align 14                   # 16 KiB, for the NAPOT region
lines:
    .fill 2048, 8, 0
