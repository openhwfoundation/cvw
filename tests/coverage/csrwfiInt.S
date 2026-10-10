///////////////////////////////////////////
// csrwfiInt.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: An interrupt enabled by a CSR write right before a wfi must be taken before the wfi executes
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

// Privileged spec 3.1.9: interrupt trap conditions must be evaluated immediately after an xRET or an
// explicit write to a CSR they depend on.  With an interrupt already pending, a csrsi mstatus.MIE,
// csrs mie, csrsi sstatus.SIE, or mret right before a wfi must trap with xepc = the wfi, which does
// not retire.
// A wfi that waits and is then woken by the interrupt still retires, with mepc = wfi+4.
// The handlers record instret, xepc and xcause at entry and return with xIE=0 and the interrupt
// still pending, so a wfi re-executed after the return falls through.  Each case checks xepc,
// xcause, the instructions retired before the trap, and that the sequence retires each
// instruction exactly once.  The cases run twice: cold and warm I$.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// Check a case in which a CSR write or mret enables an already-pending interrupt right before the wfi at
// \wfi: xepc = the wfi, xcause, two instructions (csrr, CSR write or mret) retired before the trap, and
// the sequence csrr, CSR write or mret, 7 handler instructions, wfi, nop retired once each.
// Uses indices base..base+3.
.macro CHECK_CSRWFI wfi, cause, base
    la t2, \wfi
    SC_CHECK_EQ s3, t2, \base
    li t2, \cause
    SC_CHECK_EQ s4, t2, \base+1
    sub s6, s2, s0
    li t2, 2
    SC_CHECK_EQ s6, t2, \base+2
    sub s6, s1, s0
    li t2, 11
    SC_CHECK_EQ s6, t2, \base+3
.endm

main:
    la t0, m_handler
    csrw mtvec, t0
    la t0, s_handler
    csrw stvec, t0
    li t0, 7
    csrw mcounteren, t0       # S mode may read instret
    li t0, 1
    slli t0, t0, 63
    csrs menvcfg, t0          # STCE = 1: stimecmp drives mip.STIP
    li s9, 2                  # run the cases twice; the second pass runs from a warm I$
loop:
    # Case 1: MTIP pending, mie.MTIE = 1, mstatus.MIE = 0; csrsi mstatus.MIE right before the wfi
    csrci mstatus, 8
    li t0, 0x80
    csrw mie, t0
    jal ra, setmtip
    j seq1
.align 6
seq1:
    csrr s0, minstret
    csrsi mstatus, 8          # MIE = 1: the pending interrupt must be taken here
seq1w:
    wfi
    .4byte 0x00000013         # 32-bit nop
    csrr s1, minstret
    CHECK_CSRWFI seq1w, 0x8000000000000007, 1
    jal ra, clearmtip

    # Case 2: MTIP pending, mstatus.MIE = 1, mie = 0; csrs mie.MTIE right before the wfi
    csrci mstatus, 8
    csrw mie, zero
    jal ra, setmtip
    csrsi mstatus, 8          # MIE = 1 with no interrupt enabled in mie
    li t2, 0x80
    j seq2
.align 6
seq2:
    csrr s0, minstret
    csrs mie, t2              # MTIE = 1: the pending interrupt must be taken here
seq2w:
    wfi
    .4byte 0x00000013         # 32-bit nop
    csrr s1, minstret
    CHECK_CSRWFI seq2w, 0x8000000000000007, 5
    jal ra, clearmtip

    # Case 3: the wfi waits and is woken by the interrupt: it retires and mepc = wfi+4
    csrsi mstatus, 8
    li t0, 0x80
    csrw mie, t0
    li s2, 0
    li s3, 0
    li s4, 0
    li t0, 0x0200BFF8
    ld t1, 0(t0)              # mtime
    addi t1, t1, 400
    li t0, 0x02004000
    sd t1, 0(t0)              # mtimecmp = mtime + 400
    j seq3
.align 6
seq3:
    csrr s0, minstret
seq3w:
    wfi
    .4byte 0x00000013         # 32-bit nop
    csrr s1, minstret
    addi s7, s3, -4
    la t2, seq3w
    SC_CHECK_EQ s7, t2, 9     # mepc = wfi+4
    li t2, 0x8000000000000007
    SC_CHECK_EQ s4, t2, 10
    sub s6, s2, s0
    li t2, 2                  # csrr, wfi retired before the trap
    SC_CHECK_EQ s6, t2, 11
    sub s6, s1, s0
    li t2, 10                 # csrr, wfi, 7 handler instructions, nop
    SC_CHECK_EQ s6, t2, 12
    jal ra, clearmtip

    # Case 4: MTIP pending, mie.MTIE = 1, mstatus.MIE = 0; mret with MPIE = 1 to a wfi
    csrci mstatus, 8
    li t0, 0x80
    csrw mie, t0
    jal ra, setmtip
    la t0, seq4w
    csrw mepc, t0
    li t0, 0x1880
    csrs mstatus, t0          # MPP = M, MPIE = 1
    j seq4
.align 6
seq4:
    csrr s0, minstret
    mret                      # MIE = 1: the pending interrupt must be taken before the wfi
seq4w:
    wfi
    .4byte 0x00000013         # 32-bit nop
    csrr s1, minstret
    CHECK_CSRWFI seq4w, 0x8000000000000007, 13
    jal ra, clearmtip

    # Case 5: S mode, delegated STI pending, sstatus.SIE = 0; csrsi sstatus.SIE right before the wfi
    csrci mstatus, 8
    li t0, 0x20
    csrw mideleg, t0          # delegate STI
    csrw mie, t0              # STIE only
    csrw stimecmp, zero       # STIP pending
1:
    csrr t0, mip
    andi t0, t0, 0x20
    beqz t0, 1b               # wait for mip.STIP
    li a0, 1
    ecall                     # enter S mode
    csrci sstatus, 2          # SIE = 0
    li s2, 0
    li s3, 0
    li s4, 0
    j seq5
.align 6
seq5:
    csrr s0, instret
    csrsi sstatus, 2          # SIE = 1: the pending interrupt must be taken here
seq5w:
    wfi
    .4byte 0x00000013         # 32-bit nop
    csrr s1, instret
    CHECK_CSRWFI seq5w, 0x8000000000000005, 17
    li a0, 3
    ecall                     # back to M mode
    li t0, -1
    csrw stimecmp, t0
    csrw mideleg, zero

    addi s9, s9, -1
    bnez s9, loop
    SC_PASS
    j done

setmtip:
    li s2, 0
    li s3, 0
    li s4, 0
    li t0, 0x02004000
    sd zero, 0(t0)            # mtimecmp = 0: MTIP pending
1:
    csrr t0, mip
    andi t0, t0, 0x80
    beqz t0, 1b               # wait for mip.MTIP
    .rept 8
    nop                       # retire past the reference model's interrupt latency window
    .endr
    ret

clearmtip:
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)              # mtimecmp = max: clear the timer interrupt
1:
    csrr t0, mip
    andi t0, t0, 0x80
    bnez t0, 1b               # wait for mip.MTIP to clear
    ret

.align 4
m_handler:
    csrr s2, minstret         # count at handler entry
    csrr s3, mepc
    csrr s4, mcause
    bgez s4, m_exception
    li s5, 0x80
    csrc mstatus, s5          # MPIE = 0: return with MIE=0 so a re-executed wfi falls through
    mret
m_exception:
    j trap_handler            # ecalls change privilege or end the test

.align 4
s_handler:
    csrr s2, instret          # count at handler entry
    csrr s3, sepc
    csrr s4, scause
    bgez s4, s_exception
    li s5, 0x20
    csrc sstatus, s5          # SPIE = 0: return with SIE=0 so a re-executed wfi falls through
    sret
s_exception:
    SC_FAIL 0x20
