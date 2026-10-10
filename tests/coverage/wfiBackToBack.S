///////////////////////////////////////////
// wfiBackToBack.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: An interrupt taken on the second of two back-to-back wfi instructions must not also retire that wfi
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
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

// M-mode, mstatus.MIE=1, mie.MTIE=1.  A wfi woken by the machine timer interrupt retires and the
// interrupt is taken on the next instruction.  When that instruction is a second wfi, the hart must
// either retire it and trap with mepc after it, or trap with mepc = the second wfi and not retire it.
// The handler records minstret, mepc and mcause at entry and returns with MIE=0 and the interrupt
// still pending, so a wfi re-executed after mret falls through.  Each case checks that minstret
// counts every instruction of the sequence exactly once and that mepc is the first instruction not
// retired before the trap.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

main:
    la t0, b2b_handler
    csrw mtvec, t0
    li s9, 2                  # run the cases twice; the second pass runs from a warm I$
loop:
    # Case 1: two wfi; the interrupt arrives while the first one waits
    li s2, 0
    li s3, 0
    li s4, 0
    li t0, 0x0200BFF8
    ld t1, 0(t0)              # mtime
    addi t1, t1, 400
    li t0, 0x02004000
    sd t1, 0(t0)              # mtimecmp = mtime + 400
    j seq1
.align 6
seq1:
    csrr s0, minstret
seq1w1:
    wfi
    wfi
    csrr s1, minstret
    jal ra, clearint
    sub s6, s1, s0
    li s7, 10                 # csrr, wfi, wfi, 7 handler instructions
    SC_CHECK_EQ s6, s7, 1
    sub s6, s2, s0
    addi s6, s6, -1           # wfi instructions retired before the trap
    slli s6, s6, 2
    la s7, seq1w1
    add s7, s7, s6            # first instruction not retired before the trap
    SC_CHECK_EQ s3, s7, 2
    li s7, 0x8000000000000007
    SC_CHECK_EQ s4, s7, 3

    # Case 2: a single wfi woken by the interrupt; the trap is taken on the following instruction
    li s2, 0
    li s3, 0
    li s4, 0
    li t0, 0x0200BFF8
    ld t1, 0(t0)              # mtime
    addi t1, t1, 400
    li t0, 0x02004000
    sd t1, 0(t0)              # mtimecmp = mtime + 400
    j seq2
.align 6
seq2:
    csrr s0, minstret
seq2w1:
    wfi
    .4byte 0x00000013         # 32-bit nop
    csrr s1, minstret
    jal ra, clearint
    sub s6, s1, s0
    li s7, 10                 # csrr, wfi, nop, 7 handler instructions
    SC_CHECK_EQ s6, s7, 4
    sub s6, s2, s0
    addi s6, s6, -1           # wfi/nop instructions retired before the trap
    slli s6, s6, 2
    la s7, seq2w1
    add s7, s7, s6            # first instruction not retired before the trap
    SC_CHECK_EQ s3, s7, 5
    li s7, 0x8000000000000007
    SC_CHECK_EQ s4, s7, 6

    addi s9, s9, -1
    bnez s9, loop
    SC_PASS
    j done

clearint:
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)              # mtimecmp = max: clear the timer interrupt
1:
    csrr t0, mip
    andi t0, t0, 0x80
    bnez t0, 1b               # wait for mip.MTIP to clear
    csrsi mstatus, 8          # MIE = 1
    ret

.align 4
b2b_handler:
    csrr s2, minstret         # count at handler entry
    csrr s3, mepc
    csrr s4, mcause
    bgez s4, b2b_exception
    li s5, 0x80
    csrc mstatus, s5          # MPIE = 0: return with MIE=0 so a re-executed wfi falls through
    mret
b2b_exception:
    j trap_handler            # ecall from done
