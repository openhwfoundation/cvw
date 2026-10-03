///////////////////////////////////////////
// hpmcounters.S
//
// Written: David_Harris@hmc.edu 18 September 2026
//
// Purpose: Exercise the hardware performance monitor counters in csrc.sv.
//
//          Counters 3 and above only increment when their event selector is nonzero
//          (CounterInc[i] = CounterEvent[i] & ~MCOUNTINHIBIT_REGW[i] & (MHPMEVENT_REGW[i] != 0)),
//          so nothing in that expression is exercised until a test writes mhpmevent.  This test
//          writes every mhpmevent, toggles every mcountinhibit bit, generates each of the events
//          csrc.sv counts, and writes and reads every mhpmcounter so the per-counter address
//          decode is covered for each index.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
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

// Write a nonzero event selector to every mhpmevent, including the ones whose event source is
// tied to zero, so that the (MHPMEVENT_REGW[i] != 0) term is exercised for every counter index.
.macro SET_ALL_EVENTS val
    li t0, \val
    csrw mhpmevent3,  t0
    csrw mhpmevent4,  t0
    csrw mhpmevent5,  t0
    csrw mhpmevent6,  t0
    csrw mhpmevent7,  t0
    csrw mhpmevent8,  t0
    csrw mhpmevent9,  t0
    csrw mhpmevent10, t0
    csrw mhpmevent11, t0
    csrw mhpmevent12, t0
    csrw mhpmevent13, t0
    csrw mhpmevent14, t0
    csrw mhpmevent15, t0
    csrw mhpmevent16, t0
    csrw mhpmevent17, t0
    csrw mhpmevent18, t0
    csrw mhpmevent19, t0
    csrw mhpmevent20, t0
    csrw mhpmevent21, t0
    csrw mhpmevent22, t0
    csrw mhpmevent23, t0
    csrw mhpmevent24, t0
    csrw mhpmevent25, t0
    csrw mhpmevent26, t0
    csrw mhpmevent27, t0
    csrw mhpmevent28, t0
    csrw mhpmevent29, t0
    csrw mhpmevent30, t0
    csrw mhpmevent31, t0
.endm

// Write every mhpmcounter, so WriteHPMCOUNTERM[i] is asserted for each counter index in turn.
.macro WRITE_ALL_COUNTERS val
    li t0, \val
    csrw mhpmcounter3,  t0
    csrw mhpmcounter4,  t0
    csrw mhpmcounter5,  t0
    csrw mhpmcounter6,  t0
    csrw mhpmcounter7,  t0
    csrw mhpmcounter8,  t0
    csrw mhpmcounter9,  t0
    csrw mhpmcounter10, t0
    csrw mhpmcounter11, t0
    csrw mhpmcounter12, t0
    csrw mhpmcounter13, t0
    csrw mhpmcounter14, t0
    csrw mhpmcounter15, t0
    csrw mhpmcounter16, t0
    csrw mhpmcounter17, t0
    csrw mhpmcounter18, t0
    csrw mhpmcounter19, t0
    csrw mhpmcounter20, t0
    csrw mhpmcounter21, t0
    csrw mhpmcounter22, t0
    csrw mhpmcounter23, t0
    csrw mhpmcounter24, t0
    csrw mhpmcounter25, t0
    csrw mhpmcounter26, t0
    csrw mhpmcounter27, t0
    csrw mhpmcounter28, t0
    csrw mhpmcounter29, t0
    csrw mhpmcounter30, t0
    csrw mhpmcounter31, t0
.endm

// Read every mhpmcounter, covering the machine-mode counter read path for each index.
.macro READ_ALL_COUNTERS
    csrr t1, mhpmcounter3
    csrr t1, mhpmcounter4
    csrr t1, mhpmcounter5
    csrr t1, mhpmcounter6
    csrr t1, mhpmcounter7
    csrr t1, mhpmcounter8
    csrr t1, mhpmcounter9
    csrr t1, mhpmcounter10
    csrr t1, mhpmcounter11
    csrr t1, mhpmcounter12
    csrr t1, mhpmcounter13
    csrr t1, mhpmcounter14
    csrr t1, mhpmcounter15
    csrr t1, mhpmcounter16
    csrr t1, mhpmcounter17
    csrr t1, mhpmcounter18
    csrr t1, mhpmcounter19
    csrr t1, mhpmcounter20
    csrr t1, mhpmcounter21
    csrr t1, mhpmcounter22
    csrr t1, mhpmcounter23
    csrr t1, mhpmcounter24
    csrr t1, mhpmcounter25
    csrr t1, mhpmcounter26
    csrr t1, mhpmcounter27
    csrr t1, mhpmcounter28
    csrr t1, mhpmcounter29
    csrr t1, mhpmcounter30
    csrr t1, mhpmcounter31
.endm

main:
    // Start from a known state: every counter enabled, every event selector zero.
    csrw mcountinhibit, zero
    SET_ALL_EVENTS 0
    WRITE_ALL_COUNTERS 0

    // With the selectors still zero, run the workload once.  This covers the CounterInc term
    // (MHPMEVENT_REGW[i] != 0) in its false state while the events themselves are toggling.
    jal ra, workload

    // Now enable every counter's event selector and run the workload again, so each CounterInc
    // expression is exercised with the selector nonzero and its event both high and low.
    SET_ALL_EVENTS 1
    jal ra, workload

    // Inhibit every counter and repeat, toggling ~MCOUNTINHIBIT_REGW[i] for each index.
    li t0, -1
    csrw mcountinhibit, t0
    jal ra, workload

    // Release the inhibit one more time so the counters resume incrementing.
    csrw mcountinhibit, zero
    jal ra, workload

    // Write and read back every counter, covering the per-counter write decode and read mux.
    WRITE_ALL_COUNTERS 0x123
    READ_ALL_COUNTERS

    // The unprivileged shadows of the first three counters are read-only; read them too.
    csrr t1, cycle
    csrr t1, time
    csrr t1, instret

    j done

// Generate one of each event csrc.sv counts: branches taken and not taken, jumps, returns,
// mispredictions, load and store stalls, data and instruction cache accesses and misses,
// CSR writes, fence.i, sfence.vma, an exception, and a divide.
workload:
    mv s1, ra                   # workload is called with jal, so save the return address

    # Branches, both directions, and a loop whose final branch mispredicts.
    li t0, 16
1:  addi t0, t0, -1
    andi t1, t0, 1
    beqz t1, 2f                 # alternates taken and not taken
    nop
2:  bnez t0, 1b                 # loop back edge, mispredicts on the last iteration

    # Jumps and returns, exercising the return address stack.
    jal ra, leaf
    jal ra, leaf

    # Loads and stores.  The stride is larger than a cache line so successive accesses miss,
    # producing data cache accesses, misses and the resulting load and store stalls.
    la t2, scratch
    li t3, 8
3:  sd t3, 0(t2)
    ld t4, 0(t2)
    addi t2, t2, 128            # skip a cache line each time
    addi t3, t3, -1
    bnez t3, 3b

    # A dependent load-use pair, which stalls in the memory stage so the load stall event fires.
    la t2, scratch
    ld t4, 0(t2)
    add t5, t4, t4              # uses the loaded value immediately
    sd t5, 8(t2)
    ld t6, 8(t2)
    add t6, t6, t6

    # CSR write event.
    csrr t0, mscratch
    csrw mscratch, t0

    # Instruction cache invalidate, so later fetches miss.
    fence.i

    # TLB flush.
    sfence.vma

    # A divide, for the divider busy event.
    li t0, 1000
    li t1, 7
    div t2, t0, t1
    remu t3, t0, t1

    # An exception: read a nonexistent CSR from machine mode.  The trap handler in
    # WALLY-init-lib.h skips the faulting instruction and returns.
    csrr t0, 0xBFF

    mv ra, s1
    ret

leaf:
    ret

.section .data
.align 12
scratch:
    .fill 256, 8, 0
