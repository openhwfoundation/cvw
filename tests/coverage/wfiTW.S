///////////////////////////////////////////
// wfiTW.S
//
// Written David_Harris@hmc.edu 10/6/26
//
// Purpose: wfi bounded by the mstatus.TW time limit: woken before the limit it completes (and an
//          enabled interrupt is taken with mepc = wfi+4); at the limit it raises an illegal-instruction
//          exception with mepc = the wfi and does not retire.  In U mode with S implemented the limit
//          applies even when TW = 0 (Privileged Spec mstatus_tw_op, mstatus_tw_umode_op, wfi_mepc_val).
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

// The handler records mcause, mepc and the minstret it reads as its third instruction (rec_*).
// That count minus the instret read just before the wfi is 3 if the wfi trapped (csrr and two handler
// instructions retired) and 4 if the wfi retired first.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.option norvc                   # the handler skips 4-byte instructions

main:
    la t0, tw_handler
    csrw mtvec, t0
    csrw mie, zero
    csrci mstatus, 8            # M-mode interrupts off; S/U-mode run with M interrupts enabled by definition
    li t0, 1
    slli t0, t0, 63
    csrs menvcfg, t0            # menvcfg.STCE = 1: stimecmp drives STIP
    li t0, 7
    csrw mcounteren, t0         # S mode may read cycle, time, instret and write stimecmp
    csrw scounteren, t0         # U mode may read them
    li t0, -1
    csrw stimecmp, t0
    li t0, 0x20
    csrw mie, t0                # mie.STIE = 1: STIP wakes the wfi
    li t0, 0x200000
    csrs mstatus, t0            # mstatus.TW = 1
    li a0, 1
    ecall                       # S mode, sstatus.SIE = 0

    # Case 1: STI delegated and disabled (SIE = 0) wakes the wfi before the limit: it completes, no trap
    li t0, 0x20
    jal ra, setdeleg            # mideleg = STI
    jal ra, clearrec
    li a3, 200
    jal ra, trial
    la t2, rec_cause
    ld t2, 0(t2)
    SC_CHECK_EQ t2, zero, 1     # no trap
    sub t2, s1, s0
    li t3, 2
    SC_CHECK_EQ t2, t3, 2       # csrr and wfi retired
    li t2, -1
    csrw stimecmp, t2           # clear the pending STIP before STI is undelegated

    # Case 2: STI not delegated, so enabled in S mode: woken before the limit, the wfi retires and the
    # interrupt is taken with mepc = wfi+4
    li t0, 0
    jal ra, setdeleg
    jal ra, clearrec
    li a3, 200
    jal ra, trial
    la t3, rec_cause
    ld t2, 0(t3)
    li t4, 0x8000000000000005
    SC_CHECK_EQ t2, t4, 3
    ld t2, 8(t3)
    la t4, wfi_instr
    addi t4, t4, 4
    SC_CHECK_EQ t2, t4, 4       # mepc = wfi+4
    ld t2, 16(t3)
    sub t2, t2, s0
    li t4, 4
    SC_CHECK_EQ t2, t4, 5       # wfi retired before the trap

    # Case 3: no interrupt: the TW limit raises an illegal instruction on the wfi, which does not retire
    jal ra, clearrec
    li a3, -1                   # never
    jal ra, trial
    la t3, rec_cause
    ld t2, 0(t3)
    li t4, 2
    SC_CHECK_EQ t2, t4, 6
    ld t2, 8(t3)
    la t4, wfi_instr
    SC_CHECK_EQ t2, t4, 7       # mepc = wfi
    ld t2, 16(t3)
    sub t2, t2, s0
    li t4, 3
    SC_CHECK_EQ t2, t4, 8       # wfi not retired

    # Case 4: U mode with TW = 0: the limit still applies because S mode is implemented
    li t0, 0x200000
    jal ra, cleartw             # TW = 0 (M-mode service)
    li a0, 0
    ecall                       # U mode
    jal ra, clearrec
    li a3, -1
    jal ra, trial
    la t3, rec_cause
    ld t2, 0(t3)
    li t4, 2
    SC_CHECK_EQ t2, t4, 10
    ld t2, 8(t3)
    la t4, wfi_instr
    SC_CHECK_EQ t2, t4, 11
    ld t2, 16(t3)
    sub t2, t2, s0
    li t4, 3
    SC_CHECK_EQ t2, t4, 12      # wfi not retired

    li a0, 3
    ecall                       # back to M mode
    SC_PASS
    j done

// Run one wfi with STIP due a3 cycles after stimecmp is written (a3 = -1: never).
// s0 = instret before the wfi; s1 = instret after it.
trial:
    j wfiseq
.align 6                        # keep the timed sequence in one I$ line
wfiseq:
    li t2, -1
    beq a3, t2, 1f              # never: stimecmp is already disarmed (and not writable in U mode)
    csrr t2, time
    add t2, t2, a3
    csrw stimecmp, t2
1:
    csrr s0, instret
wfi_instr:
    wfi
    csrr s1, instret            # an illegal-instruction trap returns here (mepc + 4)
    ret

// M-mode services, reached by ecall with a0 = 5 (mideleg = t0) or a0 = 6 (clear mstatus bits t0)
setdeleg:
    li a0, 5
    ecall
    ret
cleartw:
    li a0, 6
    ecall
    ret

clearrec:
    la t2, rec_cause
    sd zero, 0(t2)
    sd zero, 8(t2)
    sd zero, 16(t2)
    ret

.align 4
tw_handler:
    csrrw tp, mscratch, tp      # tp = trap stack
    sd t0, 0(tp)
    csrr t0, minstret           # third handler instruction
    sd t0, -16(tp)
    sd t1, -8(tp)
    csrr t0, mcause
    bltz t0, tw_int
    li t1, 2
    beq t0, t1, tw_ill
    addi t0, t0, -8
    bltz t0, tw_bad
    li t1, 3
    bgt t0, t1, tw_bad
    li t1, 5                    # ecall: a0 = 5 sets mideleg, a0 = 6 clears mstatus bits
    beq a0, t1, tw_deleg
    li t1, 6
    beq a0, t1, tw_mstatus
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler              # privilege changes and test end
tw_deleg:
    ld t0, 0(tp)
    csrw mideleg, t0
    j tw_skip
tw_mstatus:
    ld t0, 0(tp)
    csrc mstatus, t0
    j tw_skip
tw_int:
    jal t1, tw_record
    li t0, -1
    csrw stimecmp, t0           # clear STIP; return to mepc
    j tw_ret
tw_ill:
    jal t1, tw_record
    li t0, -1
    csrw stimecmp, t0
tw_skip:
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
tw_ret:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
tw_record:                      # record mcause, mepc, minstret; return through t1
    la t0, rec_cause
    sd a4, -24(tp)
    csrr a4, mcause
    sd a4, 0(t0)
    csrr a4, mepc
    sd a4, 8(t0)
    ld a4, -16(tp)
    sd a4, 16(t0)
    ld a4, -24(tp)
    jr t1
tw_bad:
    csrrw tp, mscratch, tp
    SC_FAIL 0x30

.section .data
.align 3
rec_cause:
    .dword 0                    # mcause
    .dword 0                    # mepc
    .dword 0                    # minstret at handler entry
