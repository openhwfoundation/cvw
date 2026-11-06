///////////////////////////////////////////
// WALLY-plic-stress-02.S
//
// Purpose: PLIC gateway, claim, priority, and threshold stress test for context 0 (M mode):
//          level-sensitive gateways (pending set, held while the line drops, not re-pended while
//          in progress, re-pended at completion if still asserted), priority 0, claim ordering by
//          priority and by ID, claim with nothing pending, priority/enable/threshold changes while
//          pending, and the full priority x threshold grid for both contexts.
//          Expected values follow the RISC-V PLIC Specification v1.0.0 (riscv-plic.adoc).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"
#include "WALLY-plic.h"

INIT_TESTS

TRAP_HANDLER m

PLIC_EXPECTED_BEGIN

    PLIC_SRC_INIT
    QUIESCE

// =============================================================================================
// 1. Each source's gateway sets its own pending bit ("Interrupt Gateways": the first assertion of
//    a level is converted into a request, indicated by the source's IP bit; "Interrupt Pending
//    Bits": the bit for ID N is bit N mod 32 of word N/32).  Pending does not depend on enable or
//    priority; with priority 0 the source never interrupts and is not claimable ("Interrupt
//    Priorities": 0 means "never interrupt" and effectively disables the interrupt).
// =============================================================================================
    ENABLE 0, ALLSRC
.irp s, 3,6,10,11,12,13,14
    SRC_HIGH \s
    CHKR(PLIC_PEND0, 1<<\s)
    CHKMIP(0)                           // priority 0: never interrupts
    CLAIM(0, 0)                         // and is not claimed
    CHKR(PLIC_PEND0, 1<<\s)             // so it stays pending
    SRC_LOW \s
    CHKR(PLIC_PEND0, 1<<\s)             // the gateway cannot retract a forwarded request
    PRIO \s, 1
    CHKMIP(MIP_MEIP)
    CLAIM(0, \s)
    CHKR(PLIC_PEND0, 0)                 // the claim clears the IP bit
    CHKMIP(0)
    COMPLETE 0, \s
    SETTLE
    CHKR(PLIC_PEND0, 0)                 // the line is low: no new request after completion
    PRIO \s, 0
.endr
    QUIESCE

// =============================================================================================
// 2. Level held high across claim and completion ("Interrupt Gateways": no further request until
//    the completion message; on completion, if the level is still asserted, a new request is
//    forwarded).
// =============================================================================================
    ENABLE 0, ALLSRC
    PRIO 3, 2
    SRC_HIGH 3
    CHKR(PLIC_PEND0, 1<<3)
    CHKMIP(MIP_MEIP)
    CLAIM(0, 3)
    SETTLE 200
    CHKR(PLIC_PEND0, 0)                 // in progress: no new request although the line is high
    CHKMIP(0)
    CLAIM(0, 0)                         // nothing else pending
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)              // still asserted at completion: pending again
    CHKMIP(MIP_MEIP)
    CLAIM(0, 3)
    CHKR(PLIC_PEND0, 0)
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 0)
    CHKMIP(0)
    // a level that pulses while the source is in progress is not remembered (one request at most)
    SRC_HIGH 3
    CLAIM(0, 3)
    SRC_LOW 3
    SRC_HIGH 3
    SRC_LOW 3
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 0)
    CLAIM(0, 0)
    // a claim that returns 0 marks nothing in progress: a later request is still accepted
    CLAIM(0, 0)
    SRC_HIGH 3
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

// =============================================================================================
// 3. Claim ordering ("Interrupt Priorities": ties are broken by ID, lowest ID first; "Interrupt
//    Claim Process": a claim returns the highest-priority pending interrupt, or 0 if none).
//    The lines stay high so that each claimed source stays in progress and out of the way.
// =============================================================================================
    // all at priority 1: ascending ID order
    ENABLE 0, ALLSRC
.irp s, 3,6,10,11,12,13,14
    PRIO \s, 1
.endr
    SRC_ALL_HIGH
    CHKR(PLIC_PEND0, (1<<3)|(1<<6)|(1<<10)|(1<<11)|(1<<12)|(1<<13)|(1<<14))
.irp s, 3,6,10,11,12,13,14
    CHKMIP(MIP_MEIP)
    CLAIM(0, \s)
.endr
    CHKMIP(0)
    CLAIM(0, 0)
    SRC_ALL_LOW
.irp s, 3,6,10,11,12,13,14
    COMPLETE 0, \s
.endr
    SETTLE
    CHKR(PLIC_PEND0, 0)
    QUIESCE

    // all at priority 7: ascending ID order
    ENABLE 0, ALLSRC
.irp s, 3,6,10,11,12,13,14
    PRIO \s, 7
.endr
    SRC_ALL_HIGH
.irp s, 3,6,10,11,12,13,14
    CLAIM(0, \s)
.endr
    CLAIM(0, 0)
    QUIESCE

    // mixed priorities: 11 (7), 12 (7), 6 (5), 14 (5), 10 (3), 13 (2), 3 (1)
    ENABLE 0, ALLSRC
    PRIO 3, 1
    PRIO 6, 5
    PRIO 10, 3
    PRIO 11, 7
    PRIO 12, 7
    PRIO 13, 2
    PRIO 14, 5
    SRC_ALL_HIGH
.irp s, 11,12,6,14,10,13,3
    CLAIM(0, \s)
.endr
    CLAIM(0, 0)
    QUIESCE

    // descending priority by ID: 3 (1) ... 14 (7): highest ID first
    ENABLE 0, ALLSRC
    PRIO 3, 1
    PRIO 6, 2
    PRIO 10, 3
    PRIO 11, 4
    PRIO 12, 5
    PRIO 13, 6
    PRIO 14, 7
    SRC_ALL_HIGH
.irp s, 14,13,12,11,10,6,3
    CLAIM(0, \s)
.endr
    CLAIM(0, 0)
    QUIESCE

    // a source that becomes pending later but with higher priority is claimed first; a lower
    // priority source that arrives while others are pending waits its turn
    ENABLE 0, ALLSRC
    PRIO 3, 4
    PRIO 6, 6
    PRIO 10, 2
    SRC_HIGH 3
    SRC_HIGH 10
    SRC_HIGH 6
    CLAIM(0, 6)
    CLAIM(0, 3)
    CLAIM(0, 10)
    CLAIM(0, 0)
    QUIESCE

// =============================================================================================
// 4. Changing priority or enable while pending takes effect on the next claim and on EIP.
// =============================================================================================
    ENABLE 0, ALLSRC
    PRIO 3, 1
    PRIO 10, 1
    SRC_HIGH 3
    SRC_HIGH 10
    PRIO 10, 2                          // 10 now outranks 3
    CLAIM(0, 10)
    CLAIM(0, 3)
    SRC_LOW 3
    SRC_LOW 10
    COMPLETE 0, 3
    COMPLETE 0, 10
    QUIESCE

    ENABLE 0, ALLSRC
    PRIO 3, 5
    SRC_HIGH 3
    CHKMIP(MIP_MEIP)
    PRIO 3, 0                           // priority 0 while pending: never interrupts
    CHKMIP(0)
    CLAIM(0, 0)
    CHKR(PLIC_PEND0, 1<<3)              // still pending
    PRIO 3, 5
    CHKMIP(MIP_MEIP)
    ENABLE 0, 0                         // disabled while pending
    CHKMIP(0)
    CLAIM(0, 0)
    CHKR(PLIC_PEND0, 1<<3)
    ENABLE 0, 1<<3
    CHKMIP(MIP_MEIP)
    THRESH 0, 5                         // threshold raised to the source's priority
    CHKMIP(0)
    THRESH 0, 4
    CHKMIP(MIP_MEIP)
    CLAIM(0, 3)
    CHKMIP(0)
    // priority changed while claimed (in progress): no effect until completion
    PRIO 3, 7
    THRESH 0, 0
    CHKMIP(0)
    CHKR(PLIC_PEND0, 0)
    COMPLETE 0, 3
    SETTLE
    CHKMIP(MIP_MEIP)
    CLAIM(0, 3)
    QUIESCE

// =============================================================================================
// 5. Threshold ("Priority Thresholds": the PLIC masks all interrupts of priority <= threshold;
//    threshold 0 permits all interrupts with non-zero priority).  EIP for every priority x
//    threshold pair, in each context.  The claim is not affected by the threshold ("Interrupt
//    Claim Process": "the claim operation is not affected by the setting of the priority
//    threshold register").
// =============================================================================================
    ENABLE 0, 1<<3
    SRC_HIGH 3
.irp t, 0,1,2,3,4,5,6,7
    THRESH 0, \t
.irp p, 0,1,2,3,4,5,6,7
    PRIO 3, \p
    CHKMIP(((\p > \t) & 1) * MIP_MEIP)
.endr
.endr
    THRESH 0, 7
    PRIO 3, 7
    CHKMIP(0)
    CLAIM(0, 3)                         // priority == threshold: masked from EIP but claimable
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

    ENABLE 1, 1<<3
    SRC_HIGH 3
.irp t, 0,1,2,3,4,5,6,7
    THRESH 1, \t
.irp p, 0,1,2,3,4,5,6,7
    PRIO 3, \p
    CHKMIP(((\p > \t) & 1) * MIP_SEIP)
.endr
.endr
    THRESH 1, 7
    PRIO 3, 2
    CHKMIP(0)
    CLAIM(1, 3)                         // priority < threshold: masked from EIP but claimable
    SRC_LOW 3
    COMPLETE 1, 3
    PW PLIC_EN1, 0
    QUIESCE

    END_TESTS

PLIC_HELPERS

TEST_STACK_AND_DATA

PLIC_EXPECTED_END
