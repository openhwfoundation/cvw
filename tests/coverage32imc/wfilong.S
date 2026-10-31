///////////////////////////////////////////
// wfilong.S
//
// Written: david_harris@hmc.edu 27 October 2026
//
// Purpose: rv32imc wfi time limit coverage (trl5 group D).  Wally counts the cycles a wfi waits and
//          raises an illegal instruction once the count reaches 2^WFI_TIMEOUT_BIT (2^16) if mstatus.TW = 1
//          and the wfi is below M mode.  Without S mode, a U-mode wfi with TW = 0 may wait indefinitely.
//          1. U mode, TW = 0: the wfi waits past the time limit, then the machine timer interrupt
//             ends it; no illegal instruction.
//          2. M mode, TW = 1: TW does not apply in M mode, so the wfi likewise waits past the limit
//             until the interrupt.
//          Each wait is about 0x14000 cycles; the test checks that mtime advanced past 0x10000 and that
//          the only trap was the timer interrupt.
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

#define MTIME      0x0200BFF8
#define MTIMECMP   0x02004000
#define MCAUSE_MTI 0x80000007
#define WAIT       0x14000

// SCHEDULE: s1 = mtime (low word); mtimecmp = mtime + WAIT
.macro SCHEDULE
    li t2, MTIME
    lw s1, 0(t2)
    lw t4, 4(t2)
    li t3, WAIT
    add t5, s1, t3
    sltu t6, t5, s1
    add t4, t4, t6
    li t2, MTIMECMP
    li t6, -1
    sw t6, 4(t2)
    sw t5, 0(t2)
    sw t4, 4(t2)
.endm

// CHECK_WAIT index: exactly one trap, a machine timer interrupt, at least 0x10000 mtime ticks after s1
.macro CHECK_WAIT index
    li t2, 1
    SC_CHECK_EQ s3, t2, \index          // one interrupt
    SC_CHECK_EQ s4, zero, \index + 1    // no exception
    sub t2, s2, s1
    li t3, 0x10000
    bgeu t2, t3, 8f
    SC_FAIL \index + 2                  // the wfi did not wait past the time limit
8:
.endm

main:
    la t0, wfi_trap
    csrw mtvec, t0
    li t0, 0x80
    csrw mie, t0                        // MTIE only

    // 1. U mode, mstatus.TW = 0
    li t0, 0x200000
    csrc mstatus, t0                    // TW = 0
    li s3, 0                            // interrupts
    li s4, 0                            // exceptions other than ecall
    SCHEDULE
    li a0, 0
    ecall                               // to U mode
    wfi
    nop
    li a0, 3
    ecall                               // back to M mode
    CHECK_WAIT 1

    // 2. M mode, mstatus.TW = 1, mstatus.MIE = 1
    li t0, 0x200000
    csrs mstatus, t0                    // TW = 1
    csrsi mstatus, 8                    // MIE = 1
    li s3, 0
    li s4, 0
    SCHEDULE
    wfi
    nop
    CHECK_WAIT 4
    li t0, 0x200000
    csrc mstatus, t0                    // TW = 0

    la t0, trap_handler
    csrw mtvec, t0
    SC_PASS
    j done

.align 4
wfi_trap:
    csrrw tp, mscratch, tp
    sw t0, 0(tp)
    sw t1, -4(tp)
    csrr t0, mcause
    bgez t0, wfi_exception
    li t1, MCAUSE_MTI
    bne t0, t1, wfi_bad
    li t0, MTIME
    lw s2, 0(t0)                        // time the interrupt was taken
    li t0, -1
    li t1, MTIMECMP
    sw t0, 4(t1)                        // no further timer interrupt
    sw t0, 0(t1)
    addi s3, s3, 1
    lw t1, -4(tp)
    lw t0, 0(tp)
    csrrw tp, mscratch, tp
    mret                                // the interrupt returns after the wfi
wfi_exception:
    addi t1, t0, -8                     // ecall from U (8) or M (11): change privilege
    beqz t1, 1f
    addi t1, t0, -11
    beqz t1, 1f
    addi s4, s4, 1                      // anything else: count it (fails the check) and skip it
1:  lw t1, -4(tp)
    lw t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler
wfi_bad:
    SC_FAIL 0xF1
