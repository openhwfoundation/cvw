///////////////////////////////////////////
// cbofaulthit.S
//
// Written: David_Harris@hmc.edu 3 October 2026
//
// Purpose: Test coverage for a cbo.inval that hits in the data cache but takes an access fault.
//          The hit asks the way to clear its valid bit, and in the same cycle the access's own
//          fault squashes it (lsu.sv SelfFaultM, part of LSUFlushW), which must cancel the clear.
//          Four lines that share a set are loaded first, so the faulting cbo.invals hit in each
//          of the four ways.  Each line is then stored to, so it holds data memory does not:
//          reading it back after the faults shows the clear was cancelled.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// CHECKTRAP n, cause, epc, tval, index: trap n recorded by record_trap had mcause = cause,
// mepc = epc and mtval = tval (registers).  Uses a1 = traps.
.macro CHECKTRAP n, cause, epc, tval, index
    ld t2, 8+24*\n(a1)
    SC_CHECK_EQ t2, \cause, \index
    ld t2, 16+24*\n(a1)
    SC_CHECK_EQ t2, \epc, \index+1
    ld t2, 24+24*\n(a1)
    SC_CHECK_EQ t2, \tval, \index+2
.endm

main:
    la t0, record_trap
    csrw mtvec, t0
    li t0, 0xF0             # menvcfg.CBZE, CBCFE and CBIE, so supervisor mode may use cbo.inval
    csrw menvcfg, t0

    // Load four lines 4 KiB apart: they share a set, so they fill all four ways.  Store each line's
    // address into it, so the line is dirty and holds a value memory does not.
    la s0, lines
    li s1, 4096
    mv t0, s0
    li t1, 4
fill:
    ld t2, 0(t0)
    sd t0, 0(t0)
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

    li a0, 3                # back to machine mode, which the unlocked PMP regions do not restrict
    ecall

    // Traps: the ecall from machine mode, a store/AMO access fault on each cbo.inval with mtval =
    // the line's address, and the ecall from supervisor mode
    la a1, traps
    ld t2, 0(a1)
    li t3, 6
    SC_CHECK_EQ t2, t3, 1
    li a2, 11
    ld t2, 8(a1)
    SC_CHECK_EQ t2, a2, 2
    li a2, 7
    la a3, inval
    mv a4, s0
    CHECKTRAP 1, a2, a3, a4, 3
    add a4, a4, s1
    CHECKTRAP 2, a2, a3, a4, 6
    add a4, a4, s1
    CHECKTRAP 3, a2, a3, a4, 9
    add a4, a4, s1
    CHECKTRAP 4, a2, a3, a4, 12
    li a2, 9
    ld t2, 8+24*5(a1)
    SC_CHECK_EQ t2, a2, 15

    // The faults cancelled the valid-bit clears, so each line still holds its dirty data
    mv a4, s0
    li a5, 4
readback:
    ld t2, 0(a4)
    SC_CHECK_EQ_ADR t2, a4, a4, 16
    add a4, a4, s1
    addi a5, a5, -1
    bnez a5, readback

    SC_PASS
    j done

// Record mcause, mepc and mtval of each trap in traps, then continue in the library trap handler.
// The faulting cbo.invals run in supervisor mode, which cannot read these CSRs itself.
.align 4
record_trap:
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    la t1, traps
    ld t2, 0(t1)                # number of traps so far
    addi t3, t2, 1
    sd t3, 0(t1)
    li t3, 8
    bgeu t2, t3, 1f             # the table holds the first 8
    slli t3, t2, 1
    add t3, t3, t2
    slli t3, t3, 3
    add t1, t1, t3              # t1 = traps + 24 * n
    csrr t2, mcause
    sd t2, 8(t1)
    csrr t2, mepc
    sd t2, 16(t1)
    csrr t2, mtval
    sd t2, 24(t1)
1:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j trap_handler

.data
// The trap record must not share the D$ set of the lines (address bits 11:6 = 0), or the
// handler would evict one of them before its cbo.inval
.align 12
.skip 2048                  // address bits 11:6 = 32
traps:                      // number of traps, then mcause, mepc, mtval of each
    .fill 1+3*8, 8, 0
.align 14                   // 16 KiB, for the NAPOT region
lines:
    .fill 2048, 8, 0
