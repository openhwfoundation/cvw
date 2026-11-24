///////////////////////////////////////////
// fdivstall32.S
//
// Written David_Harris@hmc.edu 24 November 2026
//
// Purpose: An FP divide that a Memory-stage stall holds in Execute as its last iteration finishes must wait in
//          the divider's DONE state and keep its result.  On rv64gc integer divides reach this; on rv32gc only
//          FP divides use the FPU divider.  The testbench stall injector (slti x0, x0, imm with
//          imm = {length, delay}) raises ExternalStall; sweeping the delay places the stall on each cycle of
//          the divide, including the last.  Standalone (WALLY-init-lib.h is RV64 only); the outcome is recorded
//          in selfcheck_record in the WALLY-selfcheck.h format and reported to tohost (1 = pass, 5 = fail).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

.option norvc

#define STALL_LEN 3

// a0 = 1.0 / 3.0 = 0x3EAAAAAB (inexact, so the divider runs all its iterations rather than stopping early)
.macro TRYFDIV dly
.align 6
    slti x0, x0, (STALL_LEN << 6) | \dly # arm the stall injector
    fdiv.s ft2, ft0, ft1
    fmv.x.w a0, ft2
    li a3, \dly
    bne a0, s2, fail
.endm

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
    csrci mstatus, 8                    # MIE = 0: no interrupts
    li t0, 0x2000                       # mstatus.FS = Initial: enable the FPU
    csrs mstatus, t0
    li t0, 0x3F800000                   # 1.0
    fmv.w.x ft0, t0
    li t0, 0x40400000                   # 3.0
    fmv.w.x ft1, t0
    li s2, 0x3EAAAAAB                   # 1.0 / 3.0 rounded to nearest
    .set d, 0
    .rept 24
    TRYFDIV d
    .set d, d+1
    .endr
    la t0, selfcheck_record
    li t1, 1                            # status 1: passed
    sw t1, 0(t0)
    li t0, 1                            # report pass to tohost
    j finish

fail:                                   # status 2: index, address (unused), expected, actual
    la t0, selfcheck_record
    li t1, 2
    sw t1, 0(t0)
    sw a3, 4(t0)
    sw zero, 8(t0)
    sw s2, 12(t0)
    sw a0, 16(t0)
    li t0, (2 << 1) | 1                 # report failure (exit code 2) to tohost

finish:
    la t1, tohost
    sw t0, 0(t1)                        # a store word to tohost ends the simulation
self_loop:
    j self_loop

.section .tohost
tohost:
    .word 0
fromhost:
    .word 0

.data
.globl begin_signature
begin_signature:
    .word 0
.globl selfcheck_record
selfcheck_record:
    .fill 8, 4, 0
