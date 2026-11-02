///////////////////////////////////////////
// wfiStallWake.S
//
// Written David_Harris@hmc.edu 10/13/26
//
// Purpose: An enabled interrupt that ends a wfi's wait must be taken after the wfi (mepc = wfi + 4), even
//          when the wait ends while Memory is still stalled for another reason.  Here the testbench stall
//          injector holds ExternalStall across the wake, so the wfi stays in Memory after its wait ends.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// The stall injector (slti x0, x0, imm with imm = {length, delay}) holds ExternalStall for 63 cycles, starting
// 8 cycles after it retires, while the wfi after it is waiting.  The loop sweeps the time at which the machine
// timer interrupt arrives across that window.  The interrupt always arrives after the wfi has started waiting,
// so it must never be taken on the wfi itself.

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.option norvc

.equ START, 24
.equ END, 96

main:
    la t0, m_trap
    csrw mtvec, t0
    li t0, 0x80
    csrs mie, t0                        # MTIE
    li s0, START                        # cycles from reading mtime until the timer interrupt
    li s1, 0                            # interrupts taken on the wfi
    li s2, 0                            # interrupts taken after the wfi
    li s3, END
    j loop

.align 6
loop:
    li t0, 0x0200BFF8
    ld t1, 0(t0)                        # mtime
    add t1, t1, s0
    li t0, 0x02004000
    sd t1, 0(t0)                        # mtimecmp = mtime + s0
    csrsi mstatus, 8                    # MIE = 1
    slti x0, x0, -56                    # imm = {63, 8}: ExternalStall for 63 cycles, 8 cycles from now
wfi_instr:
    wfi
    csrci mstatus, 8                    # MIE = 0
    addi s0, s0, 1
    blt s0, s3, loop
    SC_CHECK_EQ s1, zero, 1             # an interrupt was taken on the wfi
    li t0, END - START
    SC_CHECK_EQ s2, t0, 2               # every iteration took exactly one interrupt after the wfi
    SC_PASS
    j done

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
    j trap_handler                      # ecalls: termination (WALLY-init-lib.h)
m_int:                                  # machine timer interrupt
    li t0, -1
    li t1, 0x02004000
    sd t0, 0(t1)                        # mtimecmp = max to clear the interrupt
    csrr t0, mepc
    la t1, wfi_instr
    bne t0, t1, m_int_after
    addi s1, s1, 1                      # taken on the wfi: skip it, or it would wait forever
    addi t0, t0, 4
    csrw mepc, t0
    j m_int_ret
m_int_after:
    addi t1, t1, 4
    bne t0, t1, m_int_ret
    addi s2, s2, 1
m_int_ret:
    ld t1, -24(tp)
    ld t0, -16(tp)
    csrrw tp, mscratch, tp
    mret
