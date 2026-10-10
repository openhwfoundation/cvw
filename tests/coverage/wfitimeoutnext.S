///////////////////////////////////////////
// wfitimeoutnext.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: A wfi woken on the last cycle before its timeout must not make the next instruction trap
//
// The wfi runs in S mode with mstatus.TW = 1, so it raises an illegal-instruction exception when it
// waits 2^WFI_TIMEOUT_BIT cycles.  It is woken by a supervisor timer interrupt (Sstc stimecmp,
// delegated, enabled in mie but not taken because sstatus.SIE = 0).  A binary search over the
// stimecmp delay finds the boundary between waking and timing out, and the delays around the
// boundary are then rerun.  The only legal illegal-instruction trap is on the wfi itself; a trap on
// the instruction after it fails the test.
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

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.option norvc                   # the trap handler skips 4-byte instructions

main:
    la t0, wto_handler
    csrw mtvec, t0              # record illegal-instruction traps; anything else goes to sc_trap_handler
    csrw mie, zero              # mie.MTIE = 0: only the supervisor timer may wake the wfi
    li t0, 0x20
    csrw mideleg, t0            # delegate STI, so it is not taken in S mode while sstatus.SIE = 0
    li t0, 1
    slli t0, t0, 63
    csrs menvcfg, t0            # menvcfg.STCE = 1: stimecmp drives STIP
    csrsi mcounteren, 2         # mcounteren.TM = 1: S mode can read time and write stimecmp
    li t0, -1
    csrw stimecmp, t0           # no supervisor timer interrupt yet
    li t0, 0x20
    csrw mie, t0                # mie.STIE = 1: a pending STI wakes the wfi
    li t0, 0x200000
    csrs mstatus, t0            # mstatus.TW = 1: wfi below M mode times out
    li a0, 1
    ecall                       # switch to S mode with sstatus.SIE = 0

    la s3, wfi_instr
    li s0, 0                    # lo: largest delay known to wake the wfi
    li s1, 0x20000              # hi: smallest delay known to time out (2^17 exceeds the timeout)
search:
    addi t2, s0, 1
    beq t2, s1, sweep
    add s2, s0, s1
    srli s2, s2, 1
    jal ra, trial
    beqz a1, search_woke
    mv s1, s2                   # timed out
    j search
search_woke:
    mv s0, s2                   # woke without a trap
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

// Run one wfi with STIP due s2 cycles after stimecmp is written.
// Returns a1 = mepc of the illegal-instruction trap, or 0 if the wfi was woken.
trial:
    la t0, trap_epc
    sd zero, 0(t0)
    j wfiseq
.align 6                        # keep the timed sequence in one I$ line
wfiseq:
    csrr t2, time
    add t2, t2, s2
    csrw stimecmp, t2
wfi_instr:
    wfi
    addi a2, a2, 1              # must not take the wfi timeout trap
    li t2, -1
    csrw stimecmp, t2           # clear STIP
    la t0, trap_epc
    ld a1, 0(t0)
    beqz a1, 1f
    SC_CHECK_EQ a1, s3, 1       # only the wfi itself may trap
1:
    ret

.align 4
wto_handler:
    csrrw tp, mscratch, tp      # tp = trap stack
    sd t0, 0(tp)
    sd t1, -8(tp)
    csrr t0, mcause
    li t1, 2
    bne t0, t1, wto_other
    csrr t0, mepc
    la t1, trap_epc
    sd t0, 0(t1)                # record which instruction trapped
    addi t0, t0, 4
    csrw mepc, t0               # and skip it
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
wto_other:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    j sc_trap_handler           # ecalls go on to trap_handler; any other trap fails the test

.section .data
.align 3
trap_epc:
    .dword 0
