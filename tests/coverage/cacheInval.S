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
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
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
        li t0, 0x80108000
        sd zero, 0(t0)
        ld t1, 0(t0)
        li t0, 0x80109000
        sd zero, 0(t0)
        ld t1, 0(t0)

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
        .rept 256
        fence.i
        .endr

        // The trap_handler in WALLY-init-lib.h disables the timer (mtimecmp = -1) and
        // returns into the middle of the burst, which then runs to completion.

        // A few more fence.i interleaved with control flow for good measure.
        fence.i
        jal primer
        fence.i

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
