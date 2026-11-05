///////////////////////////////////////////
// rasupdates.S
//
// Written: David_Harris@hmc.edu 1 November 2026
//
// Purpose: Coverage test for return address stack updates that happen in the same cycle (issue 610).
//          The RAS pops in Fetch, repairs a mispredicted return class or a flushed return in Decode,
//          and pushes in Execute.  Each scenario below lines two of these up in one cycle:
//            empty:  call to a function that is just ret: the call pushes in E while the ret,
//                    predicted in D, has already popped
//            one:    call to a one-instruction function: push in E while the ret pops in F
//            chain:  return to a return (a tail ret after a call through x5)
//            dec:    a ret predicted as a jump (class repair in D) while the next instruction,
//                    aliased in the BTB with a return, pops in F
//            incr:   call whose target is aliased with a return: push in E while D repairs the
//                    target's wrong return prediction
//            flush:  call predicted as a jump to the next instruction, which is aliased with a
//                    return: push in E while D flushes that predicted return
//          The aliases rely on the BTB index wrapping every 4 KiB (BTB_SIZE = 10).  Each scenario
//          runs inside a wrapper whose own return checks that the stack is intact; a RAS mistake
//          only costs a misprediction, so the checks are on the values the calls compute.
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

.option norvc                   // fixed 4-byte instructions so the 4 KiB aliases line up

main:
        li a0, 0                // incremented once per scenario per iteration
        li s1, 8                // iterations; the first ones train the BTB
loop:
        jal ra, level1
        addi s1, s1, -1
        bnez s1, loop
        li t5, 8*7
        SC_CHECK_EQ a0, t5, 1
        SC_PASS
        j done

        // Run every scenario; level1's own return checks the stack below the wrappers.
level1:
        mv s2, ra
        jal ra, w_empty
        jal ra, w_one
        jal ra, w_chain
        jal ra, w_dec
        jal ra, w_incr
        jal ra, w_flush
        jal ra, w_nest
        mv ra, s2
        ret

w_empty:
        mv s3, ra
        jal ra, empty
        addi a0, a0, 1
        mv ra, s3
        ret
empty:
        ret

w_one:
        mv s3, ra
        jal ra, one
        mv ra, s3
        ret
one:
        addi a0, a0, 1
        ret

w_chain:
        mv s3, ra
        jal t0, chain2          // call through x5
        mv ra, s3
        ret
chain2:
        jal ra, chain3
        jr t0                   // return through x5, reached from chain3's ret
chain3:
        addi a0, a0, 1
        nop
        nop
        ret

        // A ret predicted as a jump: trains blockA+8 as a jump to blockA+12 (through blockB+8)
        // and blockA+12 as a return (through blockB+12), then calls into blockA.
w_dec:
        mv s3, ra
        la t2, 1f
        j blockB_jdec           // jumps to blockA+12, which jumps back through t2
1:      jal ra, blockB_rdec     // ret at blockB+12
        jal ra, blockA_dec      // ret at blockA+8, predicted as a jump to blockA+12
        addi a0, a0, 1
        mv ra, s3
        ret

        // A call to a function whose first instruction is aliased with a return.
w_incr:
        mv s3, ra
        jal ra, blockB_rincr    // ret at blockB+16 trains blockA+16 as a return
        jal ra, blockA_incr     // blockA+16 is predicted as a return
        mv ra, s3
        ret

        // A call predicted as a jump to the next instruction, which is aliased with a return.
w_flush:
        mv s3, ra
        la t2, 1f
        j blockB_jflush         // jumps to blockA+28, which jumps back through t2
1:      jal ra, blockB_rflush   // ret at blockB+28 trains blockA+28 as a return
        la t2, 2f
        j blockA_flush          // call at blockA+24, predicted as a jump to blockA+28
2:      mv ra, s3
        ret
flushee:
        addi a0, a0, 1
        nop
        ret

        // Deeper nesting with the coinciding updates below a live entry.
w_nest:
        mv s4, ra
        jal ra, w_empty2
        mv ra, s4
        ret
w_empty2:
        mv s3, ra
        jal ra, empty
        jal ra, one
        addi a0, a0, -1         // w_empty2 adds 1 overall, from one
        addi a0, a0, 1
        mv ra, s3
        ret

.align 12
blockA:
        nop                     // blockA+0
        nop                     // blockA+4
blockA_rdec:
        ret                     // blockA+8: aliased with the jump at blockB+8
        jr t2                   // blockA+12: aliased with the ret at blockB+12
blockA_incr:
        addi a0, a0, 1          // blockA+16: aliased with the ret at blockB+16
        ret                     // blockA+20
blockA_flush:
        jal ra, flushee         // blockA+24: aliased with the jump at blockB+24
        jr t2                   // blockA+28: aliased with the ret at blockB+28
.equ blockA_dec, blockA

.align 12
blockB:
        nop                     // blockB+0
        nop                     // blockB+4
blockB_jdec:
        j blockA+12             // blockB+8
blockB_rdec:
        ret                     // blockB+12
blockB_rincr:
        ret                     // blockB+16
        nop                     // blockB+20
blockB_jflush:
        j blockA+28             // blockB+24
blockB_rflush:
        ret                     // blockB+28
