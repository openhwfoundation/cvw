///////////////////////////////////////////
// cacheInval.S
//
// Written: David_Harris@hmc.edu 27 October 2026 (RV32 port of tests/coverage64gc/cacheInval.S)
//
// Purpose: Coverage test for the I$ invalidate path on rv32gc: the FEC row InvalidateFlushStage_1 of
//          (InvalidateCache & ~InvalidateFlushStage) in cachefsm.sv, cacheLRU.sv and cacheway.sv.
//          InvalidateCache is InvalidateICacheM (fence.i in the Memory stage) and InvalidateFlushStage
//          is FlushW (TrapM).  A plain fence.i never asserts FlushW, so a machine timer interrupt is
//          armed to fire during a long burst of back-to-back fence.i instructions; the interrupt is
//          taken on a fence.i in the Memory stage, so InvalidateICacheM and FlushW are both 1.
//
//          Checks: the D$ priming loads return the stored values; the timer interrupt was taken
//          (mcause) on a fence.i inside the burst (mepc); and self-modifying code works: a function
//          run once (so it is in the I$) is overwritten with a store, and after fence.i the next
//          call runs the new instruction.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

main:
        // Prime the I$ with code spread across several lines, then fence.i, repeated, so the invalidate
        // path operates on valid/LRU state
        jal primer
        fence.i
        jal primer
        fence.i
        fence.i             // back-to-back fence.i

        // Prime the D$; each line holds its own address, checked after the burst
        li t0, 0x80108000
        sw t0, 0(t0)
        lw a1, 0(t0)
        li t0, 0x80109000
        sw t0, 0(t0)
        lw a2, 0(t0)
        csrw mcause, zero       // the check after the burst reads the cause of the timer interrupt

        // Arm the machine timer to fire shortly into the fence.i burst.  MTIE and MIE are set by
        // WALLY-init-lib.h.  mtimecmp is written low word = -1 first, so no write leaves it in the past
        // until the final low word.
        li   t2, 0x0200BFF8     // MTIME
        li   t4, 0x02004000     // MTIMECMP
        li   t5, -1
        sw   t5, 0(t4)
        lw   t6, 4(t2)          // mtime high word
        sw   t6, 4(t4)
        lw   t3, 0(t2)          // mtime low word
        addi t3, t3, 8          // small delta so the interrupt fires shortly into the burst
        sw   t3, 0(t4)          // arm timer interrupt

        // Long run of back-to-back fence.i; the timer interrupt is taken while one is in the Memory stage
burst_start:
        .rept 256
        fence.i
        .endr
burst_end:

        fence.i
        jal primer
        fence.i

        // Checks, after the timing-sensitive sequence
        li t5, 0x80108000
        SC_CHECK_EQ a1, t5, 1
        li t5, 0x80109000
        SC_CHECK_EQ a2, t5, 2

        // The machine timer interrupt was taken, on a fence.i in the burst.  The library handler returns
        // past the interrupted instruction, so mepc is its address + 4.
        csrr a3, mcause
        li t5, 0x80000007
        SC_CHECK_EQ a3, t5, 3
        csrr a3, mepc
        addi a3, a3, -4
        la t5, burst_start
        bltu a3, t5, 1f
        la t5, burst_end
        bltu a3, t5, 2f
1:      SC_FAIL 4
2:

        // Self-modifying code.  smc_fn returns a0 = 1.  Run it so its line is in the I$, then overwrite its
        // first instruction with addi a0, x0, 2.  After fence.i, the next call must run the new instruction.
        jal smc_fn
        li t5, 1
        SC_CHECK_EQ a0, t5, 5
        la a3, smc_fn
        li a4, 0x00200513       // addi a0, x0, 2
        sw a4, 0(a3)
        fence.i
        jal smc_fn
        li t5, 2
        SC_CHECK_EQ a0, t5, 6

        SC_PASS
        j done

// Subroutine spread over several cache lines so executing it fills multiple I$ sets/ways
.align 6
primer:
        nop
        nop
        nop
        nop
        jal t6, primer2
        nop
        nop
        ret

.align 6
primer2:
        nop
        nop
        nop
        nop
        jr t6

// Function rewritten by the self-modifying code check, on its own cache line
.align 6
smc_fn:
        .word 0x00100513        // addi a0, x0, 1 (a 32-bit encoding, so one word store replaces it)
        ret
