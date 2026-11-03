///////////////////////////////////////////
// wrsWait.S
//
// Written David_Harris@hmc.edu 10/6/26
//
// Purpose: Zawrs wrs.nto / wrs.sto waits on a single hart.  Each wait ends on the right condition:
//          no reservation (completes at once), wrs.sto's short timeout (completes), a locally enabled
//          pending interrupt (completes; an enabled interrupt is then taken with mepc = wrs+4), or, for
//          wrs.nto below M mode with mstatus.TW = 1, the time limit (illegal instruction, mepc = wrs,
//          not retired).  wrs.nto does not trap in U mode when TW = 0, and an interrupt already enabled
//          and pending is taken on the wrs itself.  The result of the lr before a wrs is forwarded
//          across the wait.
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

// Short timeout 2^WRSSTO_TIMEOUT_BIT = 2^12 cycles; wrs.nto TW limit 2^WRSNTO_TIMEOUT_BIT = 2^13 cycles (rv64gc).
// The handler records mcause, mepc and the minstret it reads as its third instruction; that count
// minus the instret read just before the wrs is 3 if the wrs trapped and 4 if it retired first.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.option norvc                   # the handler skips 4-byte instructions

#define WRS_NTO .4byte 0x00d00073
#define WRS_STO .4byte 0x01d00073
#define MTIMECMP 0x02004000

main:
    la t0, wr_handler
    csrw mtvec, t0
    csrw mie, zero
    csrci mstatus, 8
    csrw mideleg, zero
    li t0, 1
    slli t0, t0, 63
    csrs menvcfg, t0            # menvcfg.STCE = 1: stimecmp drives STIP
    li t0, 7
    csrw mcounteren, t0
    csrw scounteren, t0
    li t0, -1
    csrw stimecmp, t0
    la s8, resv                 # reservation address
    li s9, 0x5a5a1234           # value it holds
    sd s9, 0(s8)
    li s10, 2                   # run the M-mode cases twice: cold and warm I$
mloop:
    # Case 1: no reservation: both complete at once
    lr.d t0, (s8)
    sc.d t0, t0, (s8)           # clears the reservation
    jal ra, clearrec
    csrr s0, time
    WRS_NTO
    WRS_STO
    csrr s1, time
    sub t2, s1, s0
    li t3, 100
    bltu t2, t3, 1f
    SC_FAIL 1
1:  la t2, rec_cause
    ld t2, 0(t2)
    SC_CHECK_EQ t2, zero, 2

    # Case 2: reservation, wrs.sto completes after its short timeout; the lr result is forwarded across it
    li a0, 7
    j c2
.align 6
c2: csrr s0, time
    lr.d a0, (s8)
    WRS_STO
    addi a1, a0, 0
    csrr s1, time
    SC_CHECK_EQ a1, s9, 3
    sub t2, s1, s0
    li t3, 0x1000
    bgeu t2, t3, 1f
    SC_FAIL 4                   # ended before the short timeout
1:  li t3, 0x4000
    bltu t2, t3, 1f
    SC_FAIL 5                   # not a short timeout
1:
    # Case 3: reservation, wrs.nto in M mode with interrupts globally off waits for the timer (past the
    # TW limit, which does not apply in M mode) and completes
    li t0, 0x80
    csrw mie, t0                # MTIE
    li a1, 0x8000
    jal ra, setmtime            # MTIP due in 0x8000 cycles
    li a0, 7
    j c3
.align 6
c3: csrr s0, time
    lr.d a0, (s8)
    WRS_NTO
    sd a0, 8(s8)                # store data forwarded across the wait
    csrr s1, time
    ld a1, 8(s8)
    SC_CHECK_EQ a1, s9, 6
    sub t2, s1, s0
    li t3, 0x7000
    bgeu t2, t3, 1f
    SC_FAIL 7                   # did not wait for the interrupt
1:  jal ra, clearmtime
    csrw mie, zero

    # Case 4: interrupt already enabled and pending when the wrs executes: taken on the wrs itself
    li t0, 0x80
    csrw mie, t0
    li a1, 0
    jal ra, setmtime            # MTIP pending now
1:  csrr t0, mip
    andi t0, t0, 0x80
    beqz t0, 1b
    jal ra, clearrec
    j c4
.align 6
c4: lr.d a0, (s8)
    csrr s0, minstret
    csrsi mstatus, 8            # MIE = 1: the interrupt is taken on the next instruction
c4w:
    WRS_STO                     # re-executed after the handler, it ends at the latest on its short timeout
    la t3, rec_cause
    ld t2, 0(t3)
    li t4, 0x8000000000000007
    SC_CHECK_EQ t2, t4, 8
    ld t2, 8(t3)
    la t4, c4w
    SC_CHECK_EQ t2, t4, 9       # mepc = the wrs
    jal ra, clearmtime
    csrw mie, zero

    addi s10, s10, -1
    bnez s10, mloop

    # S mode, TW = 1
    li t0, 0x200000
    li a0, 7
    ecall                       # set mstatus.TW
    li a0, 1
    ecall                       # S mode

    # Case 5: wrs.nto hits the TW limit: illegal instruction on the wrs, which does not retire
    jal ra, clearrec
    j c5
.align 6
c5: lr.d a0, (s8)
    csrr s0, instret
c5w:
    WRS_NTO
    la t3, rec_cause
    ld t2, 0(t3)
    li t4, 2
    SC_CHECK_EQ t2, t4, 10
    ld t2, 8(t3)
    la t4, c5w
    SC_CHECK_EQ t2, t4, 11      # mepc = the wrs
    ld t2, 16(t3)
    sub t2, t2, s0
    li t4, 3
    SC_CHECK_EQ t2, t4, 12      # not retired

    # Case 6: wrs.sto is not bounded by TW: it completes on its short timeout
    jal ra, clearrec
    j c6
.align 6
c6: csrr s0, time
    lr.d a0, (s8)
    WRS_STO
    csrr s1, time
    la t3, rec_cause
    ld t2, 0(t3)
    SC_CHECK_EQ t2, zero, 13
    sub t2, s1, s0
    li t3, 0x1000
    bgeu t2, t3, 1f
    SC_FAIL 14
1:
    # Case 7: U mode, TW = 0: wrs.nto waits past the TW limit for an (enabled, undelegated) STI, retires,
    # and the interrupt is taken with mepc = wrs+4
    li t0, 0x200000
    li a0, 6
    ecall                       # clear mstatus.TW
    li t0, 0x20
    csrw sie, zero
    li a0, 8
    ecall                       # mie = STIE
    csrr t0, time
    li t1, 0x9000
    add t0, t0, t1
    csrw stimecmp, t0           # STIP due past the TW limit
    li a0, 0
    ecall                       # U mode
    jal ra, clearrec
    j c7
.align 6
c7: lr.d a0, (s8)
    csrr s0, instret
c7w:
    WRS_NTO
    la t3, rec_cause
    ld t2, 0(t3)
    li t4, 0x8000000000000005
    SC_CHECK_EQ t2, t4, 15
    ld t2, 8(t3)
    la t4, c7w
    addi t4, t4, 4
    SC_CHECK_EQ t2, t4, 16      # mepc = wrs+4
    ld t2, 16(t3)
    sub t2, t2, s0
    li t4, 4
    SC_CHECK_EQ t2, t4, 17      # retired

    li a0, 3
    ecall                       # M mode
    SC_PASS
    j done

setmtime:                       # mtimecmp = mtime + a1
    li t0, 0x0200BFF8
    ld t1, 0(t0)
    add t1, t1, a1
    li t0, MTIMECMP
    sd t1, 0(t0)
    ret
clearmtime:                     # mtimecmp = max; wait for MTIP to clear
    li t0, -1
    li t1, MTIMECMP
    sd t0, 0(t1)
1:  csrr t0, mip
    andi t0, t0, 0x80
    bnez t0, 1b
    ret
clearrec:
    la t2, rec_cause
    sd zero, 0(t2)
    sd zero, 8(t2)
    sd zero, 16(t2)
    ret

// M-mode handler.  ecall services: a0 = 6 clears mstatus bits t0, a0 = 7 sets them, a0 = 8 writes mie = t0;
// a0 = 0..4 go on to trap_handler.  Interrupts disarm both timers and return with MPIE = 0; an illegal
// instruction is skipped.  Anything else fails.
.align 4
wr_handler:
    csrrw tp, mscratch, tp      # tp = trap stack
    sd t0, 0(tp)
    csrr t0, minstret           # third handler instruction
    sd t0, -16(tp)
    sd t1, -8(tp)
    csrr t0, mcause
    bltz t0, wr_int
    li t1, 2
    beq t0, t1, wr_ill
    addi t0, t0, -8
    bltz t0, wr_bad
    li t1, 3
    bgt t0, t1, wr_bad
    li t1, 6
    beq a0, t1, wr_clr
    li t1, 7
    beq a0, t1, wr_set
    li t1, 8
    beq a0, t1, wr_mie
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler
wr_clr:
    ld t0, 0(tp)
    csrc mstatus, t0
    j wr_skip
wr_set:
    ld t0, 0(tp)
    csrs mstatus, t0
    j wr_skip
wr_mie:
    ld t0, 0(tp)
    csrw mie, t0
    j wr_skip
wr_int:
    jal t1, wr_record
    li t0, -1
    csrw stimecmp, t0
    li t1, MTIMECMP
    sd t0, 0(t1)
    li t0, 0x80
    csrc mstatus, t0            # MPIE = 0
    j wr_ret
wr_ill:
    jal t1, wr_record
wr_skip:
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
wr_ret:
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
wr_record:                      # record mcause, mepc, minstret; return through t1
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
wr_bad:
    csrrw tp, mscratch, tp
    SC_FAIL 0x30

.section .data
.align 3
rec_cause:
    .dword 0                    # mcause
    .dword 0                    # mepc
    .dword 0                    # minstret at handler entry
.align 6
resv:
    .dword 0
    .dword 0
