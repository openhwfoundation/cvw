///////////////////////////////////////////
// trapcsrstall.S
//
// Written David_Harris@hmc.edu 10/5/26
//
// Purpose: A trap that is pending while the pipeline is stalled must not write the trap CSRs of a privilege
//          mode it never enters.  A delegated (S-mode) illegal instruction sits in Memory under an external
//          stall when a machine timer interrupt arrives, so the interrupt is taken instead; sepc, scause and
//          stval must keep their old values.
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

// The testbench stall injector (slti x0, x0, imm with imm = {length, delay}) holds ExternalStall for 31 cycles
// from the cycle the illegal instruction reaches Memory.  The loop sweeps the time at which the machine timer
// interrupt arrives across that window.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.option norvc

main:
    csrci mstatus, 8                    # MIE = 0: the timer interrupt is taken only in S mode
    li t0, 4
    csrw medeleg, t0                    # illegal instruction traps go to S mode
    la t0, s_trap
    csrw stvec, t0
    la t0, m_trap
    csrw mtvec, t0
    li s3, 0x1E                         # sentinel scause
    li s4, 0x80001234                   # sentinel sepc
    li s5, 0x5A5A5A5A                   # sentinel stval
    li s0, 0                            # cycles from reading mtime until the timer interrupt
    li s1, 0                            # number of interrupts taken on the illegal instruction
    li s2, 100

loop:
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)                        # mtimecmp = max: no interrupt yet
    csrw scause, s3
    csrw sepc, s4
    csrw stval, s5
    li a0, 1
    ecall                               # enter S mode
    li t0, 0x0200BFF8
    ld t1, 0(t0)                        # mtime
    add t1, t1, s0
    li t0, 0x02004000
    sd t1, 0(t0)                        # mtimecmp = mtime + s0
    slti x0, x0, (31 << 6) | 0          # ExternalStall for 31 cycles as the next instruction reaches Memory
illegal_instr:
    .word 0xc0001073                    # csrrw x0, cycle, x0: illegal, delegated to S mode
    li a0, 3
    ecall                               # back to M mode
    la a2, irec
    ld t1, 24(a2)
    beqz t1, next
    sd zero, 24(a2)                     # interrupt was taken on the illegal instruction: S trap CSRs unchanged?
    addi s1, s1, 1
    ld a1, 0(a2)
    SC_CHECK_EQ a1, s3, 1
    ld a1, 8(a2)
    SC_CHECK_EQ a1, s4, 2
    ld a1, 16(a2)
    SC_CHECK_EQ a1, s5, 3
next:
    addi s0, s0, 1
    blt s0, s2, loop
    bnez s1, pass
    SC_FAIL 4                           # the interrupt never landed on the illegal instruction
pass:
    SC_PASS
    j done

.align 4
s_trap:                                 # skip the illegal instruction
    csrr t0, sepc
    addi t0, t0, 4
    csrw sepc, t0
    sret

.align 4
m_trap:
    csrrw tp, mscratch, tp              # tp = trap stack, mscratch = saved tp
    sd t0, -16(tp)
    sd t1, -24(tp)
    csrr t0, mcause
    bltz t0, m_int
    ld t1, -24(tp)
    ld t0, -16(tp)
    csrrw tp, mscratch, tp
    j trap_handler                      # ecalls: privilege changes and termination (WALLY-init-lib.h)
m_int:                                  # machine timer interrupt
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)                        # mtimecmp = max to clear the interrupt
    csrr t0, mepc
    la t1, illegal_instr
    bne t0, t1, m_int_ret
    la t1, irec                         # taken on the illegal instruction, so its S trap was not taken
    csrr t0, scause
    sd t0, 0(t1)
    csrr t0, sepc
    sd t0, 8(t1)
    csrr t0, stval
    sd t0, 16(t1)
    li t0, 1
    sd t0, 24(t1)
m_int_ret:
    ld t1, -24(tp)
    ld t0, -16(tp)
    csrrw tp, mscratch, tp
    mret

.data
.align 3
irec:                                   # scause, sepc, stval, valid
    .dword 0, 0, 0, 0
