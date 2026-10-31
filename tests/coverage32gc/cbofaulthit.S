///////////////////////////////////////////
// cbofaulthit.S
//
// Written: David_Harris@hmc.edu 27 October 2026 (RV32 port of tests/coverage64gc/cbofaulthit.S, extended)
//
// Purpose: rv32gc coverage for CMOs that hit in the data cache but take an access fault, in every way.
//          The hit asks the way to change its valid bit, and in the same cycle the access's own fault
//          squashes it (lsu.sv SelfFaultM, part of LSUFlushW = the cache's FlushStage), which must cancel
//          the change: cbo.inval (ClearValidWay & FlushStage) and cbo.zero (CMOZeroNoEviction ->
//          SetValidWay & FlushStage).  Four lines that share a set are loaded and stored first, so the
//          faulting CMOs hit in each of the four ways and each line holds dirty data memory does not:
//          reading the lines back after the faults shows the clears and the zeroing were cancelled.
//          Finally a cbo.zero from machine mode to the same no-access PMP region succeeds, because an
//          unlocked PMP entry does not restrict M mode (pmpchecker.sv PMPCBOZAccessFault with
//          EnforcePMP = 0, CMOpM[3] = 1 and MatchingW = 0).
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

#define LINEOFF 0x9C0               // the lines use D$ set 39, which the code, stacks and trap record avoid
#define NTRAPS  12                  // traps recorded

// CHECKTRAP n, cause, epc, tval, index: trap n recorded by record_trap had mcause = cause,
// mepc = epc and mtval = tval (registers).  Uses a1 = traps.
.macro CHECKTRAP n, cause, epc, tval, index
    lw t2, 4+12*\n(a1)
    SC_CHECK_EQ t2, \cause, \index
    lw t2, 8+12*\n(a1)
    SC_CHECK_EQ t2, \epc, \index+1
    lw t2, 12+12*\n(a1)
    SC_CHECK_EQ t2, \tval, \index+2
.endm

main:
    la t0, record_trap
    csrw mtvec, t0
    li t0, 0xF0             # menvcfg.CBZE, CBCFE and CBIE, so supervisor mode may use cbo.zero and cbo.inval
    csrw menvcfg, t0

    // Load four lines 4 KiB apart: they share a set, so they fill all four ways.  Store each line's
    // address into it, so the line is dirty and holds a value memory does not.
    la s0, lines
    li t0, LINEOFF
    add s0, s0, t0          # s0 = first line
    li s1, 4096
    mv t0, s0
    li t1, 4
fill:
    lw t2, 0(t0)
    sw t0, 0(t0)
    add t0, t0, s1
    addi t1, t1, -1
    bnez t1, fill

    // PMP region 0 denies all access to the 16 KiB NAPOT region holding the lines; region 2 allows
    // everything else
    la t0, lines
    srli t0, t0, 2
    ori t0, t0, 0x7FF
    csrw pmpaddr0, t0
    csrw pmpaddr1, zero
    li t0, 0xFFFFFFFF
    csrw pmpaddr2, t0
    li t0, 0x0F0018         # region 0 NAPOT no access, region 1 off, region 2 TOR RWX
    csrw pmpcfg0, t0

    li a0, 1                # supervisor mode, so the PMP applies
    ecall

    // cbo.zero needs write permission: each takes a store/AMO access fault on a hit, cancelling the zeroing
    mv t0, s0
    li t1, 4
zero:
    cbo.zero (t0)
    add t0, t0, s1
    addi t1, t1, -1
    bnez t1, zero

    // cbo.inval needs read or write permission: each takes a store/AMO access fault on a hit, cancelling
    // the valid-bit clear
    mv t0, s0
    li t1, 4
inval:
    cbo.inval (t0)
    add t0, t0, s1
    addi t1, t1, -1
    bnez t1, inval

    li a0, 3                # back to machine mode, which the unlocked PMP regions do not restrict
    ecall

    // Traps: the ecall from machine mode, a store/AMO access fault on each cbo.zero and each cbo.inval with
    // mtval = the line's address, and the ecall from supervisor mode
    la a1, traps
    lw t2, 0(a1)
    li t3, 10
    SC_CHECK_EQ t2, t3, 1
    li a2, 11
    lw t2, 4(a1)
    SC_CHECK_EQ t2, a2, 2
    li a2, 7
    la a3, zero
    mv a4, s0
    CHECKTRAP 1, a2, a3, a4, 3
    add a4, a4, s1
    CHECKTRAP 2, a2, a3, a4, 6
    add a4, a4, s1
    CHECKTRAP 3, a2, a3, a4, 9
    add a4, a4, s1
    CHECKTRAP 4, a2, a3, a4, 12
    la a3, inval
    mv a4, s0
    CHECKTRAP 5, a2, a3, a4, 15
    add a4, a4, s1
    CHECKTRAP 6, a2, a3, a4, 18
    add a4, a4, s1
    CHECKTRAP 7, a2, a3, a4, 21
    add a4, a4, s1
    CHECKTRAP 8, a2, a3, a4, 24
    li a2, 9
    lw t2, 4+12*9(a1)
    SC_CHECK_EQ t2, a2, 27

    // The faults cancelled the zeroing and the valid-bit clears, so each line still holds its dirty data
    mv a4, s0
    li a5, 4
readback:
    lw t2, 0(a4)
    SC_CHECK_EQ_ADR t2, a4, a4, 28
    add a4, a4, s1
    addi a5, a5, -1
    bnez a5, readback

    // Machine mode: the unlocked no-access region does not apply, so cbo.zero zeroes the line
    cbo.zero (s0)
    lw t2, 0(s0)
    SC_CHECK_EQ_ADR t2, zero, s0, 29
    lw t2, 0(a1)
    li t3, 10
    SC_CHECK_EQ t2, t3, 30  # no further trap

    SC_PASS
    j done

// Record mcause, mepc and mtval of each trap in traps, then continue in the library trap handler.
// The faulting CMOs run in supervisor mode, which cannot read these CSRs itself.
.align 4
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sw t1, -8(t0)
    sw t2, -12(t0)
    sw t3, -16(t0)
    la t1, traps
    lw t2, 0(t1)                # number of traps so far
    addi t3, t2, 1
    sw t3, 0(t1)
    li t3, NTRAPS
    bgeu t2, t3, 1f             # the table holds the first NTRAPS
    slli t3, t2, 1
    add t3, t3, t2
    slli t3, t3, 2
    add t1, t1, t3              # t1 = traps + 12 * n
    csrr t2, mcause
    sw t2, 4(t1)
    csrr t2, mepc
    sw t2, 8(t1)
    csrr t2, mtval
    sw t2, 12(t1)
1:  lw t3, -16(t0)
    lw t2, -12(t0)
    lw t1, -8(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j trap_handler

.data
.align 12
.skip 2048                  // traps at D$ set 32, away from the lines
traps:                      // number of traps, then mcause, mepc, mtval of each
    .fill 1+3*NTRAPS, 4, 0
.align 14                   // 16 KiB, for the NAPOT region
lines:
    .fill 4096, 4, 0
