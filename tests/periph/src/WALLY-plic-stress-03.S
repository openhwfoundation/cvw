///////////////////////////////////////////
// WALLY-plic-stress-03.S
//
// Purpose: PLIC context and completion stress test: M (context 0) and S (context 1) independence,
//          a source enabled in one context only, both contexts claiming the same source, per-context
//          thresholds, and interrupt completion with wrong, unclaimed, nonexistent, out-of-range,
//          and not-enabled IDs, from the claiming and the other context.  Also checks that a read of
//          a claim/complete address of a nonexistent context has no claim side effect.
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
// 1. A source enabled in one context only ("Interrupt Enables" are per context; "Interrupt Claim
//    Process": a claim returns the highest-priority pending interrupt for the target).
// =============================================================================================
    PRIO 3, 1
    ENABLE 1, 1<<3                      // S only
    SRC_HIGH 3
    CHKMIP(MIP_SEIP)
    CLAIM(0, 0)                         // not enabled for M: M claims nothing
    CHKR(PLIC_PEND0, 1<<3)              // and the IP bit is untouched
    CHKMIP(MIP_SEIP)
    CLAIM(1, 3)
    CHKMIP(0)
    SRC_LOW 3
    COMPLETE 1, 3
    QUIESCE

    PRIO 3, 1
    ENABLE 0, 1<<3                      // M only
    SRC_HIGH 3
    CHKMIP(MIP_MEIP)
    CLAIM(1, 0)
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(0, 3)
    CHKMIP(0)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

// =============================================================================================
// 2. Both contexts enabled: there is one IP bit per source ("Interrupt Gateways"), so the first
//    claim clears it for both contexts and the other context then claims 0.
// =============================================================================================
    PRIO 3, 1
    ENABLE 0, 1<<3
    ENABLE 1, 1<<3
    SRC_HIGH 3
    CHKMIP(MIP_MEIP | MIP_SEIP)
    CLAIM(0, 3)
    CHKMIP(0)
    CLAIM(1, 0)
    COMPLETE 0, 3
    SETTLE
    CHKMIP(MIP_MEIP | MIP_SEIP)         // still asserted: pending again, visible to both
    CLAIM(1, 3)
    CLAIM(0, 0)
    SRC_LOW 3
    COMPLETE 1, 3
    QUIESCE

    // each context picks its own highest-priority enabled source
    PRIO 3, 2
    PRIO 6, 4
    PRIO 10, 6
    ENABLE 0, (1<<3)|(1<<6)
    ENABLE 1, (1<<3)|(1<<10)
    SRC_HIGH 3
    SRC_HIGH 6
    SRC_HIGH 10
    CLAIM(1, 10)
    CLAIM(0, 6)
    CLAIM(1, 3)
    CLAIM(0, 0)
    CLAIM(1, 0)
    QUIESCE

// =============================================================================================
// 3. Thresholds are per context ("Priority Thresholds").
// =============================================================================================
    PRIO 3, 4
    ENABLE 0, 1<<3
    ENABLE 1, 1<<3
    SRC_HIGH 3
    THRESH 0, 7
    THRESH 1, 0
    CHKMIP(MIP_SEIP)
    THRESH 0, 3
    THRESH 1, 4
    CHKMIP(MIP_MEIP)
    THRESH 1, 3
    CHKMIP(MIP_MEIP | MIP_SEIP)
    THRESH 0, 4
    CHKMIP(MIP_SEIP)
    QUIESCE

// =============================================================================================
// 4. Completion ("Interrupt Completion": a write of the claimed ID to claim/complete; the PLIC does
//    not check that it is the ID last claimed by the target; "if the completion ID does not match
//    an interrupt source that is currently enabled for the target, the completion is silently
//    ignored").  The source's line stays high, so a completion that reaches its gateway shows as a
//    new pending request; one that is ignored leaves the source in progress and not pending.
// =============================================================================================
    // 4a. wrong IDs from the claiming context: an enabled source that is not in progress, 0, IDs
    //     of nonexistent sources (15, 31, 63, 1023), and IDs whose low six bits are 3 (67 = 64+3,
    //     131 = 128+3, 0x80000003, 0xFFFFFFC3)
    PRIO 3, 1
    PRIO 10, 1
    ENABLE 0, (1<<3)|(1<<10)
    SRC_HIGH 3
    CLAIM(0, 3)
.irp id, 10, 0, 15, 31, 63, 1023
    COMPLETE 0, \id
    SETTLE
    CHKR(PLIC_PEND0, 0)                 // ignored: 3 is still in progress
.endr
.irp id, 67, 131, 0x80000003, 0xFFFFFFC3
    COMPLETE 0, \id
    SETTLE
    CHKR(PLIC_PEND0, 0)                 // ID is not 3: ignored
.endr
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)              // the correct ID completes
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

    // 4b. completion from the other context, where the source is also enabled: accepted (the PLIC
    //     does not check the completion ID against the target's last claim)
    PRIO 3, 1
    ENABLE 0, 1<<3
    ENABLE 1, 1<<3
    SRC_HIGH 3
    CLAIM(0, 3)
    COMPLETE 1, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(1, 3)
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

    // 4c. completion from the other context, where the source is NOT enabled: ignored
    PRIO 3, 1
    ENABLE 0, 1<<3
    ENABLE 1, 0
    SRC_HIGH 3
    CLAIM(0, 3)
    COMPLETE 1, 3
    SETTLE
    CHKR(PLIC_PEND0, 0)                 // ignored: 3 still in progress
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

    // 4d. the source is disabled in the claiming context before completion: ignored (Linux's PLIC
    //     driver re-enables the source around the completion for exactly this reason); completing
    //     again after re-enabling works
    PRIO 3, 1
    ENABLE 0, 1<<3
    SRC_HIGH 3
    CLAIM(0, 3)
    ENABLE 0, 0
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 0)                 // ignored: 3 still in progress
    ENABLE 0, 1<<3
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

    // 4e. several sources in progress, completed out of order: each completion re-pends only its
    //     own source
    PRIO 3, 1
    PRIO 6, 1
    PRIO 10, 1
    ENABLE 0, (1<<3)|(1<<6)|(1<<10)
    SRC_HIGH 3
    SRC_HIGH 6
    SRC_HIGH 10
    CLAIM(0, 3)
    CLAIM(0, 6)
    CLAIM(0, 10)
    COMPLETE 0, 6
    SETTLE
    CHKR(PLIC_PEND0, 1<<6)
    COMPLETE 0, 10
    SETTLE
    CHKR(PLIC_PEND0, (1<<6)|(1<<10))
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, (1<<3)|(1<<6)|(1<<10))
    CLAIM(0, 3)
    CLAIM(0, 6)
    CLAIM(0, 10)
    QUIESCE

// =============================================================================================
// 5. Nonexistent contexts.  The claim/complete words of contexts 2, 3, 3072, 4096, 8192, 12288 and 4097
//    (offsets 0x202004, 0x203004, 0x0E00004, 0x1200004, 0x2200004, 0x3200004, 0x1201004) are not context 0
//    or 1: reading them must not claim, and writing them must not complete, a context 0 or 1
//    source ("Memory Map").  Reads return 0 (impl).
// =============================================================================================
    PRIO 3, 1
    ENABLE 0, 1<<3
    ENABLE 1, 1<<3
    SRC_HIGH 3
.irp a, 0x202004, 0x203004, 0x0E00004, 0x1200004, 0x2200004, 0x3200004, 0x1201004
    CHKR(\a, 0)
    CHKR(PLIC_PEND0, 1<<3)              // still pending: no claim happened
.endr
    CLAIM(0, 3)
.irp a, 0x202004, 0x203004, 0x0E00004, 0x1200004, 0x2200004, 0x3200004, 0x1201004
    PW \a, 3
    SETTLE
    CHKR(PLIC_PEND0, 0)                 // 3 still in progress: no completion happened
.endr
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

// =============================================================================================
// 6. More claim/complete corner cases.
// =============================================================================================
    // 6a. back-to-back claims (consecutive loads, no other instruction between): each returns a
    //     different source, because a claim atomically clears the IP bit ("Interrupt Claim Process")
    PRIO 3, 1
    PRIO 6, 1
    ENABLE 0, (1<<3)|(1<<6)
    SRC_HIGH 3
    SRC_HIGH 6
    li t3, PLIC + PLIC_CLAIM0
    lw t4, 0(t3)
    lw t5, 0(t3)
    lw t6, 0(t3)
    mv t2, t4
    CHKT2(3)
    mv t2, t5
    CHKT2(6)
    mv t2, t6
    CHKT2(0)
    QUIESCE

    // 6b. completing a source that is pending but was never claimed changes nothing: it stays
    //     pending and is claimed next
    PRIO 3, 1
    ENABLE 0, 1<<3
    SRC_HIGH 3
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 1<<3)
    CHKMIP(MIP_MEIP)
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

    // 6c. a source claimed while its line has already dropped: completion leaves it idle; a new
    //     assertion after completion is a new request
    PRIO 3, 1
    ENABLE 0, 1<<3
    SRC_HIGH 3
    SRC_LOW 3
    CLAIM(0, 3)
    COMPLETE 0, 3
    SETTLE
    CHKR(PLIC_PEND0, 0)
    SRC_HIGH 3
    CHKR(PLIC_PEND0, 1<<3)
    CLAIM(0, 3)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

// =============================================================================================
// 7. EIP in mip (Privileged ISA, "Machine Interrupt Registers (mip and mie)"): MEIP is read-only
//    and follows the PLIC context 0 notification; SEIP is writable by M-mode software and reads
//    as the OR of the software-written bit and the context 1 notification.
// =============================================================================================
    PRIO 3, 1
    ENABLE 1, 1<<3
    SRC_HIGH 3
    CHKMIP(MIP_SEIP)
    li t2, MIP_SEIP
    csrc mip, t2                        // the PLIC still asserts SEIP
    CHKMIP(MIP_SEIP)
    CLAIM(1, 3)
    CHKMIP(0)
    li t2, MIP_SEIP
    csrs mip, t2                        // software-written SEIP alone
    CHKMIP(MIP_SEIP)
    li t2, MIP_SEIP
    csrc mip, t2
    CHKMIP(0)
    li t2, MIP_MEIP
    csrs mip, t2                        // MEIP is read-only
    CHKMIP(0)
    SRC_LOW 3
    COMPLETE 1, 3
    QUIESCE

// =============================================================================================
// 8. The notification takes an interrupt trap: mcause = interrupt | 11 (MEI) or | 9 (SEI, not
//    delegated, taken in M).  The library's vectored handler records 0x7EC0B / 0x7EC09 and mcause,
//    then disables the GPIO interrupt and the PLIC and returns to ra.
// =============================================================================================
    PRIO 3, 1
    ENABLE 0, 1<<3
    li t2, MIP_MEIP
    csrs mie, t2
    la ra, 2f
    csrsi mstatus, 8                    // mstatus.MIE
    SRC_HIGH 3
    SETTLE 1000
    li t2, 0xBAD                        // reached only if no interrupt was taken: fill both slots
    SIGT2
    li t2, 0xBAD
    SIGT2
2:  csrci mstatus, 8
    li t2, MIP_MEIP
    csrc mie, t2
    EXPECT 0x7EC0B, __LINE__            // written by the handler
    EXPECT (1 << (__riscv_xlen-1)) | 11, __LINE__
    PLIC_SRC_INIT
    QUIESCE

    PRIO 3, 1
    ENABLE 1, 1<<3
    li t2, MIP_SEIP
    csrs mie, t2
    la ra, 3f
    csrsi mstatus, 8
    SRC_HIGH 3
    SETTLE 1000
    li t2, 0xBAD
    SIGT2
    li t2, 0xBAD
    SIGT2
3:  csrci mstatus, 8
    li t2, MIP_SEIP
    csrc mie, t2
    EXPECT 0x7EC09, __LINE__
    EXPECT (1 << (__riscv_xlen-1)) | 9, __LINE__
    PLIC_SRC_INIT
    QUIESCE

// =============================================================================================
// 9. Access width.  The PLIC registers are 32 bits wide and "accessed atomically with LW and SW"
//    ("Memory Map"); other widths are impl.  Wally's PMA (adrdecs.sv) makes the PLIC region
//    word-only, so byte, halfword and doubleword accesses take a load (mcause 5) or store (7)
//    access fault, recorded by the trap handler, and must have no effect: no register change, no
//    claim, no completion.
// =============================================================================================
    PRIO 3, 5
    ENABLE 0, 1<<3
    THRESH 0, 2
    li t3, PLIC + PLIC_PRIO + 4*3
    lbu t2, 0(t3)
    EXPECT 5, __LINE__
    lbu t2, 1(t3)
    EXPECT 5, __LINE__
    lhu t2, 2(t3)
    EXPECT 5, __LINE__
    sb zero, 0(t3)
    EXPECT 7, __LINE__
    li t3, PLIC + PLIC_EN0
    sb zero, 1(t3)
    EXPECT 7, __LINE__
    sh zero, 0(t3)
    EXPECT 7, __LINE__
    li t3, PLIC + PLIC_THRESH0
    li t2, 7
    sb t2, 0(t3)
    EXPECT 7, __LINE__
    CHKR(PLIC_PRIO+4*3, 5)
    CHKR(PLIC_EN0, 1<<3)
    CHKR(PLIC_THRESH0, 2)
    SRC_HIGH 3
    li t3, PLIC + PLIC_CLAIM0
    lbu t2, 0(t3)                       // must not claim
    EXPECT 5, __LINE__
    lhu t2, 0(t3)
    EXPECT 5, __LINE__
    CHKR(PLIC_PEND0, 1<<3)
#if __riscv_xlen == 64
    li t3, PLIC + PLIC_PEND0
    ld t2, 0(t3)
    EXPECT 5, __LINE__
    li t3, PLIC + PLIC_THRESH0
    ld t2, 0(t3)                        // threshold + claim pair: must not claim
    EXPECT 5, __LINE__
    CHKR(PLIC_PEND0, 1<<3)
#endif
    CLAIM(0, 3)
#if __riscv_xlen == 64
    li t3, PLIC + PLIC_THRESH0
    li t2, (3 << 32) | 1
    sd t2, 0(t3)                        // threshold + complete pair: must not complete or write
    EXPECT 7, __LINE__
    SETTLE
    CHKR(PLIC_PEND0, 0)
    CHKR(PLIC_THRESH0, 2)
#endif
    li t3, PLIC + PLIC_CLAIM0
    li t2, 3
    sh t2, 0(t3)                        // must not complete
    EXPECT 7, __LINE__
    SETTLE
    CHKR(PLIC_PEND0, 0)
    SRC_LOW 3
    COMPLETE 0, 3
    QUIESCE

    END_TESTS

PLIC_HELPERS

TEST_STACK_AND_DATA

PLIC_EXPECTED_END
