///////////////////////////////////////////
// rasfencei.S
//
// Written: David_Harris@hmc.edu 26 October 2026
//
// Purpose: Coverage test for the return address stack repair of flushed returns.
//          Targets the StallE_1 row of FlushedReturnDE in src/ifu/bpred/RASPredictor.sv:
//          a return in the Execute stage while E is stalled and M is flushed.
//
//          A fence.i in the Memory stage writes back the dirty lines of the data cache, so
//          LSUStallM stalls W, M and E, while CSRWriteFenceM flushes M.  A ret right behind the
//          fence.i sits in E for those cycles.  The stall keeps it there, so the RAS must not
//          treat the flush as discarding it.
//
//          Checks: each call returns to its caller and leaves the value it computed, so a
//          corrupted return address stack shows up as a wrong result or a wrong return.
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
        li s0, 0                // sum of the values the calls return
        li s1, 4                // number of calls
loop:
        jal ra, dirty_fencei_ret
        add s0, s0, a0
        addi s1, s1, -1
        bnez s1, loop
        li t5, 4*0x55
        SC_CHECK_EQ s0, t5, 1
        SC_PASS
        j done

        // Dirty eight data cache lines, then fence.i with a ret right behind it, so the ret
        // is in E while the fence.i writes the dirty lines back from M.
dirty_fencei_ret:
        la t2, scratch
        li t3, 8
dirty:
        sd t3, 0(t2)
        addi t2, t2, 64
        addi t3, t3, -1
        bnez t3, dirty
        li a0, 0x55
        fence.i
        ret

.data
.align 6
scratch:
        .fill 64, 8, 0
