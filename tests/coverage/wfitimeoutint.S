///////////////////////////////////////////
// wfitimeoutint.S
//
// Written David_Harris@hmc.edu 10/6/26
//
// Purpose: An enabled interrupt that arrives as a TW-bounded wfi reaches its time limit must give a
//          consistent trap: either the illegal-instruction exception on the wfi (mcause 2, mepc = wfi)
//          or the interrupt (mcause 0x8000000000000005, mepc = wfi or wfi+4), never a mix of the two.
//
// The wfi runs in S mode with mstatus.TW = 1.  The supervisor timer interrupt (Sstc stimecmp) is not
// delegated, so it is enabled in S mode and traps to M.  A binary search over the stimecmp delay finds
// the boundary between the interrupt and the timeout, and the delays around it are then rerun.
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

.option norvc                   # the handler skips 4-byte instructions

main:
    la t0, ti_handler
    csrw mtvec, t0
    csrw mie, zero
    csrw mideleg, zero          # STI is taken in M, so it is enabled in S mode
    li t0, 1
    slli t0, t0, 63
    csrs menvcfg, t0            # menvcfg.STCE = 1: stimecmp drives STIP
    csrsi mcounteren, 2         # mcounteren.TM = 1: S mode can read time and write stimecmp
    li t0, -1
    csrw stimecmp, t0
    li t0, 0x20
    csrw mie, t0                # mie.STIE = 1
    li t0, 0x200000
    csrs mstatus, t0            # mstatus.TW = 1
    li a0, 1
    ecall                       # S mode

    la s3, wfi_instr
    li s0, 0                    # lo: largest delay known to give the interrupt
    li s1, 0x20000              # hi: smallest delay known to time out (2^17 exceeds the limit)
search:
    addi t2, s0, 1
    beq t2, s1, sweep
    add s2, s0, s1
    srli s2, s2, 1
    jal ra, trial
    li t2, 2
    beq a1, t2, 1f
    mv s0, s2                   # interrupt
    j search
1:  mv s1, s2                   # timed out
    j search

sweep:
    li t2, 0x20000
    bne s1, t2, 1f
    SC_FAIL 2                   # the wfi never timed out
1:
    addi s2, s0, -3             # rerun the delays around the boundary
    addi s5, s1, 3
sweeploop:
    jal ra, trial
    addi s2, s2, 1
    bge s5, s2, sweeploop
    SC_PASS
    j done

// Run one wfi with STIP due s2 cycles after stimecmp is written; check the trap it ends in.
// Returns a1 = mcause.
trial:
    j wfiseq
.align 6                        # keep the timed sequence in one I$ line
wfiseq:
    csrr t2, time
    add t2, t2, s2
    csrw stimecmp, t2
wfi_instr:
    wfi
    nop                         # both traps return here: the interrupt to mepc = wfi+4, the exception to mepc+4
    la t0, trap_rec
    ld a1, 0(t0)
    ld a2, 8(t0)
    li t2, 2
    bne a1, t2, 1f
    SC_CHECK_EQ a2, s3, 3       # illegal instruction: mepc = the wfi
    ret
1:  li t2, 0x8000000000000005
    SC_CHECK_EQ a1, t2, 4       # otherwise the interrupt, with a consistent mcause
    beq a2, s3, 2f              # taken on the wfi (already pending when it executed) ...
    addi t2, s3, 4
    SC_CHECK_EQ a2, t2, 5       # ... or after it retired
2:  ret

.align 4
ti_handler:
    csrrw tp, mscratch, tp      # tp = trap stack
    sd t0, 0(tp)
    sd t1, -8(tp)
    csrr t0, mcause
    li t1, 8
    bge t0, t1, ti_ecall        # ecalls (8, 9, 11) go on to trap_handler
    la t1, trap_rec
    sd t0, 0(t1)                # record mcause and mepc
    csrr t0, mepc
    sd t0, 8(t1)
    li t1, -1
    csrw stimecmp, t1           # clear STIP
    csrr t1, mcause
    bltz t1, ti_ret             # interrupt: return to mepc
    addi t0, t0, 4
    csrw mepc, t0               # exception: skip the wfi
ti_ret:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
ti_ecall:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler

.section .data
.align 3
trap_rec:
    .dword 0                    # mcause
    .dword 0                    # mepc
