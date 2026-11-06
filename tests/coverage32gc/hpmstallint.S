///////////////////////////////////////////
// hpmstallint.S
//
// Written David_Harris@hmc.edu 10/6/26; RV32 port 27 October 2026
//
// Purpose: RV32 port of the interrupt part of tests/coverage64gc/hpmtrapcount.S.  The interrupt HPM
//          event (mhpmcounter22) must count each interrupt once, when it is taken.  An interrupt that
//          becomes pending during an ExternalStall is held in the Memory stage (TrapM with StallW) for
//          several cycles; counting every cycle of TrapM would overcount.  Covers the StallW_1 row of
//          the interrupts-taken event in csrc.sv.
//
//          Checks: 16 timer interrupts, each raised during a 31-cycle injected ExternalStall, count
//          exactly 16 in mhpmcounter22 (failure index 2) and are each seen once by the handler
//          (index 3).
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

#define MTIME    0x0200BFF8
#define MTIMECMP 0x02004000

// Interrupt during a stall: the machine timer fires during a 31-cycle ExternalStall injected by the
// testbench (slti x0, x0, imm with imm = {length, delay}).  The handler skips the interrupted instruction,
// so only nops follow the injector.  The deadlines k = 4n + 4 are spread wider than on RV64, whose single
// 64-bit mtimecmp store is quicker than the two 32-bit stores here, so that some land inside the stall
// rather than before the injector retires.  mtimecmp's high half is the maximum (set by the handler), so the
// low half is written first.
.macro STALLINT k
    li t1, MTIME
    lw t0, 0(t1)                        // mtime (low half; the test is too short for it to wrap)
    lw t2, 4(t1)
    addi t0, t0, \k
    li t1, MTIMECMP
    sw t0, 0(t1)                        // mtimecmp = mtime + k
    sw t2, 4(t1)
    slti x0, x0, (31 << 6) | 0          // ExternalStall for 31 cycles
    .rept 100
        nop
    .endr
.endm

main:
    la t0, stallint_trap
    csrw mtvec, t0
    li s3, 0                            // interrupts seen by the handler
    csrci mstatus, 8                    // no interrupts until the interrupt part
    li t0, -1
    li t1, MTIMECMP
    sw t0, 0(t1)                        // mtimecmp = max
    sw t0, 4(t1)
    li t0, 1
    csrw mhpmevent22, t0                // enable the interrupt event
    csrw mcountinhibit, zero

    // 16 timer interrupts
    csrw mhpmcounter22, zero
    csrw mhpmcounter22h, zero
    csrsi mstatus, 8
    .set n, 0
    .rept 16
        STALLINT 4*n+4
        .set n, n+1
    .endr
    csrci mstatus, 8
    csrr t2, mhpmcounter22
    li t3, 16
    SC_CHECK_EQ t2, t3, 2
    SC_CHECK_EQ s3, t3, 3

    SC_PASS
    j done

// Count interrupts in s3, then let the WALLY-init-lib.h handler set mtimecmp to the maximum and
// skip the interrupted instruction (a nop).
.align 4
stallint_trap:
    csrrw tp, mscratch, tp
    sw t0, -8(tp)
    csrr t0, mcause
    bgez t0, 1f
    addi s3, s3, 1
1:  lw t0, -8(tp)
    csrrw tp, mscratch, tp
    j trap_handler
