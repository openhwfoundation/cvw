///////////////////////////////////////////
// hpmtrapcount.S
//
// Written David_Harris@hmc.edu 10/6/26
//
// Purpose: The exception and interrupt HPM events (mhpmcounter23 and mhpmcounter22) must count each trap
//          once, when it is taken.  An exception deferred while the IFU finishes an I$ line fill (TrapM's
//          ~CommittedF term), and an interrupt pending during an ExternalStall, are held in the Memory
//          stage for several cycles; counting every cycle of TrapM overcounts.
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

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.equ RO_VA, 0x106000000                 // VPN2=4 read-only gigapage -> PA 0x86000000

// Exception deferral: a cbo.zero to a read-only page faults after its DTLB walk while an I$ line fill is
// in flight.  \k nops shift it within its I$ line so that some pass lines the fill up with the fault.
.macro DEFER k
    sfence.vma                          // cold DTLB: the cbo.zero walks, then faults
    fence.i                             // cold I$: the next fetches miss and drive a line fill
    .option push
    .option norvc
    .option norelax
    .balign 64
    .rept \k
        nop
    .endr
    cbo.zero (s1)                       // store page fault
    .rept (15 - \k)
        nop
    .endr
    nop                                 // starts a fresh (cold) I$ line
    .option pop
.endm

// Interrupt during a stall: the machine timer fires during a 31-cycle ExternalStall injected by the
// testbench (slti x0, x0, imm with imm = {length, delay}).  The handler skips the interrupted instruction,
// so only nops follow the injector.
.macro STALLINT k
    li t1, 0x0200BFF8
    ld t0, 0(t1)                        // mtime
    addi t0, t0, \k
    li t1, 0x02004000
    sd t0, 0(t1)                        // mtimecmp = mtime + k
    slti x0, x0, (31 << 6) | 0          // ExternalStall for 31 cycles
    .rept 100
        nop
    .endr
.endm

main:
    csrci mstatus, 8                    // no interrupts until the interrupt part
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)                        // mtimecmp = max
    li t0, 0xF0
    csrs menvcfg, t0                    // enable cbo.zero in S mode
    la t1, pt_root
    li t0, 0x200000C3                   // VPN2=4: V R A D, not writable
    sd t0, 32(t1)
    srli t1, t1, 12
    li t0, 8
    slli t0, t0, 60
    or t1, t1, t0
    csrw satp, t1                       // Sv39
    sfence.vma
    li s1, RO_VA
    li t0, 1
    csrw mhpmevent22, t0                // enable the interrupt and exception events
    csrw mhpmevent23, t0

    // 16 deferred store page faults and 2 ecalls: 18 exceptions
    csrw mhpmcounter23, zero
    li a0, 1
    ecall                               // enter S mode
    .set n, 0
    .rept 16
        DEFER n
        .set n, n+1
    .endr
    li a0, 3
    ecall                               // back to M mode
    csrr t2, mhpmcounter23
    li t3, 18
    SC_CHECK_EQ t2, t3, 1

    // 16 timer interrupts
    csrw mhpmcounter22, zero
    csrsi mstatus, 8
    .set n, 0
    .rept 16
        STALLINT n
        .set n, n+1
    .endr
    csrci mstatus, 8
    csrr t2, mhpmcounter22
    li t3, 16
    SC_CHECK_EQ t2, t3, 2

    SC_PASS
    j done

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF                   // VPN2=2: identity gigapage 0x80000000, V R W X A D
    .dword 0
    .dword 0                            // VPN2=4: read-only gigapage, filled at run time
    .fill 507, 8, 0
