///////////////////////////////////////////
// undelegated.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for an interrupt taken in machine mode while the hart runs in supervisor
//          or user mode with the interrupt not delegated.  trap.sv decides delegation with
//            DelegateM = (InterruptM ? MIDELEG[CauseM] : MEDELEG[CauseM]) & (mode == S | mode == U)
//          and every other test that takes an interrupt below machine mode delegates it first, so
//          the row where an interrupt arrives in S or U mode with its mideleg bit clear was never
//          reached.  Here mstatus.MIE is clear, so an interrupt made pending in machine mode waits
//          until the hart drops to supervisor or user mode, where machine interrupts are always
//          enabled, and is then taken in machine mode; the handler clears its source and returns.
//          The supervisor software, timer and external interrupts are each taken this way, plus a
//          machine software interrupt raised from supervisor mode through the CLINT.
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

#define MIP_SSIP (1 << 1)
#define MIP_MSIP (1 << 3)
#define MIP_STIP (1 << 5)
#define MIP_SEIP (1 << 9)
#define CLINT_MSIP 0x02000000

main:
    // Interrupts go to this test's handler; exceptions, which are the ecalls that change privilege
    // mode, are passed on to the library's handler.
    la t0, int_handler
    csrw mtvec, t0
    csrw mideleg, zero          # nothing is delegated (the library already left it clear)
    li t0, -1
    csrw stimecmp, t0           # keep the supervisor timer from asserting on its own
    li t0, MIP_SSIP | MIP_MSIP | MIP_STIP | MIP_SEIP
    csrw mie, t0
    csrci mstatus, 0x8          # mstatus.MIE clear: pending interrupts wait until the hart leaves M mode
    li s1, 0                    # interrupts taken

    // Supervisor software interrupt, pending when the hart enters supervisor mode
    li t0, MIP_SSIP
    csrs mip, t0
    li a0, 1
    ecall                       # supervisor mode; the interrupt is taken in machine mode at once
    nop
    nop
    li a0, 3
    ecall                       # back to machine mode

    // Supervisor timer interrupt, pending when the hart enters user mode
    li t0, MIP_STIP
    csrs mip, t0
    li a0, 0
    ecall                       # user mode
    nop
    nop
    li a0, 3
    ecall

    // Supervisor external interrupt, pending when the hart enters supervisor mode
    li t0, MIP_SEIP
    csrs mip, t0
    li a0, 1
    ecall
    nop
    nop
    li a0, 3
    ecall

    // Machine software interrupt raised from supervisor mode through the CLINT.  It can never be
    // delegated, so it is taken in machine mode from supervisor mode as well.
    li a0, 1
    ecall
    li t0, CLINT_MSIP
    li t1, 1
    sw t1, 0(t0)
    nop
    nop
    li a0, 3
    ecall

    // Restore the library's interrupt state and check that all four interrupts were taken
    csrw mie, zero
    la t0, trap_handler
    csrw mtvec, t0
    csrsi mstatus, 0x8
    li t2, 4
    SC_CHECK_EQ s1, t2, 1
    SC_PASS
    j done

// Clear the source named by mcause and count the interrupt.  Exceptions are handed to the
// library's handler with the registers as they were on entry.
.align 4
int_handler:
    csrrw tp, mscratch, tp      # borrow the trap stack, as the library handler does
    sd t0, 0(tp)
    sd t1, -8(tp)
    csrr t0, mcause
    bgez t0, int_exception
    slli t0, t0, 1              # drop the interrupt bit
    srli t0, t0, 1              # t0 = cause number
    li t1, 3
    beq t0, t1, clear_msip      # a machine software interrupt is cleared in the CLINT
    li t1, 1
    sll t1, t1, t0
    csrc mip, t1                # clear the pending bit
    j int_cleared
clear_msip:
    li t1, CLINT_MSIP
    sw zero, 0(t1)
int_cleared:
    addi s1, s1, 1
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
int_exception:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler
