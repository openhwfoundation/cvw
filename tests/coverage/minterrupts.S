///////////////////////////////////////////
// minterrupts.S
//
// Written: David_Harris@hmc.edu 18 September 2026
//
// Purpose: Take supervisor interrupts in machine mode, through a vectored trap vector.
//
//          trap.sv decides where an interrupt is taken with terms of the form
//          ~MIDELEG_REGW[n] & ValidIntsM[n].  Nothing exercises those for the supervisor
//          software, timer and external interrupts (causes 1, 5 and 9), because the tests that
//          raise them delegate them to supervisor mode first.  This test leaves mideleg clear so
//          each one is taken in machine mode instead.
//
//          The interrupts are taken through a vectored mtvec, which is also the only way to reach
//          the vectored case of the trap vector mux in csr.sv, and they are counted by an enabled
//          hardware performance monitor counter so the interrupt counter event is exercised.
//
//          WALLY-init-lib.h's handler assumes any interrupt is a timer interrupt and only clears
//          the supervisor timer, so this test installs its own handler and restores the library's
//          before finishing.
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

#define MIP_SSIP (1 << 1)
#define MIP_STIP (1 << 5)
#define MIP_SEIP (1 << 9)
#define MIE_MSIE (1 << 3)
#define CLINT_MSIP 0x02000000

main:
    // Count interrupts in a performance counter, so the interrupt counter event is exercised
    // while its selector is enabled and the counter is not inhibited.
    csrw mcountinhibit, zero
    li t0, 22
    csrw mhpmevent22, t0

    // Take interrupts in machine mode: mideleg clear means none of them are delegated.
    csrw mideleg, zero

    // Stop the supervisor timer from asserting on its own, so the only supervisor timer
    // interrupt is the one this test raises by hand.
    li t0, -1
    csrw stimecmp, t0

    // Vectored trap vector: interrupts dispatch to base + 4 * cause, exceptions to base + 0.
    la t0, vectored_trap_vector
    ori t0, t0, 1           # MODE = 1, vectored
    csrw mtvec, t0

    // Enable the three supervisor interrupts and the global enable.
    li t0, MIP_SSIP | MIP_STIP | MIP_SEIP
    csrw mie, t0
    csrsi mstatus, 0x8      # mstatus.MIE

    // Raise each one in turn.  Each is taken in machine mode because mideleg is clear, and the
    // handler below clears the pending bit so the interrupt does not repeat.
    li s1, 0                # count of interrupts taken

    li t0, MIP_SSIP
    csrs mip, t0
    nop
    nop

    li t0, MIP_STIP
    csrs mip, t0
    nop
    nop

    li t0, MIP_SEIP
    csrs mip, t0
    nop
    nop

    // Machine software interrupt, raised through the CLINT's MSIP register.
    li t0, MIE_MSIE
    csrs mie, t0
    li t0, CLINT_MSIP
    li t1, 1
    sw t1, 0(t0)
    nop
    nop

    // Now the delegated half: with mideleg set, the same interrupts are taken in supervisor mode
    // instead, which is the other half of every ~MIDELEG_REGW[n] & ValidIntsM[n] term and of the
    // delegation decision in trap.sv.
    la t0, trap_handler
    csrw mtvec, t0              # back to the library's direct handler so ecall changes privilege
    la t0, supervisor_trap_vector
    csrw stvec, t0              # direct mode
    li t0, MIP_SSIP | MIP_STIP | MIP_SEIP
    csrw mideleg, t0            # delegate the supervisor interrupts
    csrw mie, t0                # still enabled at machine level
    csrw sie, t0                # and at supervisor level
    csrs mip, t0                # raise all three; they stay pending while in machine mode
    csrsi sstatus, 0x2          # sstatus.SIE

    li a0, 1                    # drop to supervisor mode, where the delegated interrupts fire
    ecall

    // Back in supervisor mode the pending interrupts are taken one after another.  Each handler
    // disables its own source in sie, which supervisor mode is allowed to write, so it is not
    // retaken; the pending bits themselves are cleared below from machine mode.
    nop
    nop
    nop

    li a0, 3                    # return to machine mode
    ecall

    csrw mideleg, zero
    li t0, MIP_SSIP | MIP_STIP | MIP_SEIP
    csrc mip, t0                # clear the pending bits now that we are back in machine mode

    // Read the counter that was recording the interrupts.
    csrr t1, mhpmcounter22

    // Take one more interrupt with counter 22 inhibited.  Event 22 is the interrupt event itself,
    // so this is the only way to drive its CounterInc expression with the event asserted, the
    // event selector nonzero, and the counter inhibited at the same time.
    la t0, vectored_trap_vector
    ori t0, t0, 1           # MODE = 1, vectored
    csrw mtvec, t0
    li t0, 1
    slli t0, t0, 22
    csrw mcountinhibit, t0  # inhibit counter 22 only
    li t0, MIP_SSIP
    csrw mie, t0
    csrsi mstatus, 0x8      # mstatus.MIE
    csrs mip, t0
    nop
    nop
    csrw mcountinhibit, zero

    // Restore the library's direct trap vector before terminating, because done uses an ecall.
    csrci mstatus, 0x8      # mstatus.MIE off
    csrw mie, zero
    la t0, trap_handler
    csrw mtvec, t0          # MODE = 0, direct

    j done

// Vectored trap vector.  Entries must be exactly four bytes apart, so compressed instructions
// are disabled across the table.
.align 6
.option push
.option norvc
vectored_trap_vector:
    j vector_exception      # 0: exceptions arrive here in vectored mode
    j vector_interrupt      # 1: supervisor software interrupt
    j vector_interrupt      # 2: reserved
    j vector_interrupt      # 3: machine software interrupt
    j vector_interrupt      # 4: reserved
    j vector_interrupt      # 5: supervisor timer interrupt
    j vector_interrupt      # 6: reserved
    j vector_interrupt      # 7: machine timer interrupt
    j vector_interrupt      # 8: reserved
    j vector_interrupt      # 9: supervisor external interrupt
.option pop

// Clear the pending bit named by mcause so the interrupt does not immediately retrigger.
vector_interrupt:
    csrrw tp, mscratch, tp  # borrow the trap stack, as the library handler does
    sd t0, 0(tp)
    sd t1, -8(tp)
    csrr t0, mcause
    slli t0, t0, 1          # drop the interrupt bit
    srli t0, t0, 1          # t0 = cause number
    li t1, 3
    beq t0, t1, clear_msip  # a machine software interrupt is cleared in the CLINT
    li t1, 1
    sll t1, t1, t0          # mask for this interrupt
    csrc mip, t1            # clear it
    j interrupt_cleared
clear_msip:
    li t1, CLINT_MSIP
    sw zero, 0(t1)
interrupt_cleared:
    addi s1, s1, 1          # record that an interrupt was taken
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret

// Supervisor handler for the delegated interrupts.  Supervisor mode cannot clear sip.STIP or
// sip.SEIP, so disable the source in sie instead, which stops the interrupt being retaken.
.align 4
supervisor_trap_vector:
    csrr t0, scause
    bgez t0, supervisor_exception
    slli t0, t0, 1              # drop the interrupt bit
    srli t0, t0, 1              # t0 = cause number
    li t1, 1
    sll t1, t1, t0
    csrc sie, t1                # stop this interrupt being taken again
    sret

supervisor_exception:           # the ecall back to machine mode arrives here
    csrr t0, sepc
    addi t0, t0, 4
    csrw sepc, t0
    sret

// Nothing in this test should take an exception through the vectored vector, but handle it
// safely by skipping the faulting instruction rather than looping.
vector_exception:
    csrrw tp, mscratch, tp
    sd t0, 0(tp)
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
