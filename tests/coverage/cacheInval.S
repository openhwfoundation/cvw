///////////////////////////////////////////
// cacheInval.S
//
// Written: David_Harris@hmc.edu 29 May 2026
//
// Purpose: Coverage test for the shared cache invalidate path.
//          Targets the FEC condition (InvalidateCache & ~InvalidateFlushStage)
//          in src/cache/cacheLRU.sv (~140), cachefsm.sv (~128), cacheway.sv (~155).
//
//          For the instruction cache, InvalidateCache is driven by InvalidateICacheM
//          (asserted by fence.i while it is in the Memory stage) and InvalidateFlushStage
//          is driven by FlushW.  The previously uncovered FEC row is InvalidateFlushStage_1:
//          InvalidateCache=1 while InvalidateFlushStage=1.  A plain fence.i only flushes
//          D/E/M (CSRWriteFenceM) and never asserts FlushW, so it always hits the _0 row.
//          FlushW is asserted by FlushWCause = TrapM.  A trap (machine timer interrupt) is
//          asynchronous and attaches to whatever instruction occupies the Memory stage when
//          it is taken; if that instruction is a fence.i, then InvalidateICacheM=1 and
//          TrapM=1 (hence FlushW=1) in the same cycle, producing the unhit polarity.
//
//          Strategy: arm the machine timer to fire very soon, then execute a long burst of
//          back-to-back fence.i instructions so that the interrupt is overwhelmingly likely
//          to be recognized while a fence.i sits in the Memory stage.  The fence.i burst is
//          preceded by cache priming (loads + branches) so the icache has valid lines whose
//          LRU/valid state is invalidated, and the burst is long enough to absorb timer
//          jitter.
//
//          Checks: the D$ priming loads return the stored values; the timer interrupt was taken
//          (mcause) on a fence.i inside the burst (mepc); and self-modifying code works: a function
//          run once (so it is in the I$) is overwritten with a store, and after fence.i the next
//          call runs the new instruction.
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

main:
        // Prime the instruction cache by executing code spread across several
        // cache lines, then a fence.i, repeated, so the invalidate path operates
        // on valid/LRU state (covers the InvalidateCache=1 / InvalidateFlushStage=0 rows).
        jal primer
        fence.i
        jal primer
        fence.i
        fence.i             // back-to-back fence.i

        // Prime the data cache with valid lines (for context; D$ InvalidateCache is tied 0).
        // Each line holds its own address, checked after the burst.
        li t0, 0x80108000
        sd t0, 0(t0)
        ld a1, 0(t0)
        li t0, 0x80109000
        sd t0, 0(t0)
        ld a2, 0(t0)
        csrw mcause, zero       // the check after the burst reads the cause of the timer interrupt

        // ---- Arm the machine timer to fire during the fence.i burst ----
        // CLINT: MTIME @ 0x0200BFF8, MTIMECMP @ 0x02004000.  MTIE and global MIE
        // are already enabled by WALLY-init-lib.h.
        li   t2, 0x0200BFF8     // address of MTIME
        ld   t3, 0(t2)          // current time
        addi t3, t3, 8          // small delta so the interrupt fires shortly into the burst
        li   t4, 0x02004000     // address of MTIMECMP
        sd   t3, 0(t4)          // arm timer interrupt

        // ---- fence.i burst ----
        // A long run of back-to-back fence.i.  Each fence.i spends multiple cycles in the
        // Memory stage asserting InvalidateICacheM; with the timer armed to fire inside this
        // window, the trap (TrapM -> FlushW) is taken while a fence.i is in M, hitting
        // InvalidateFlushStage_1 (InvalidateCache=1 & InvalidateFlushStage=1).
burst_start:
        .rept 256
        fence.i
        .endr
burst_end:

        // The trap_handler in WALLY-init-lib.h disables the timer (mtimecmp = -1) and
        // returns into the middle of the burst, which then runs to completion.

        // A few more fence.i interleaved with control flow for good measure.
        fence.i
        jal primer
        fence.i

        // ---- Checks, after the timing-sensitive sequence ----
        li t5, 0x80108000
        SC_CHECK_EQ a1, t5, 1
        li t5, 0x80109000
        SC_CHECK_EQ a2, t5, 2

        // The machine timer interrupt was taken, on a fence.i in the burst.  The library handler returns
        // past the interrupted instruction, so mepc is its address + 4.
        csrr a3, mcause
        li t5, 0x8000000000000007
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

// Subroutine spread over several .align'd cache lines so executing it fills
// multiple icache sets/ways before invalidation.
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
