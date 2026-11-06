///////////////////////////////////////////
// WALLY-plic-stress-01.S
//
// Purpose: PLIC register-interface stress test: reset values, WARL priority and threshold
//          registers, source 0 and nonexistent sources, read-only pending bits, per-context enables,
//          reserved and nonexistent-context addresses, and aliasing within the 64 MiB PLIC region.
//          Expected values follow the RISC-V PLIC Specification v1.0.0 (riscv-plic.adoc); "impl"
//          marks values the spec leaves to the implementation (see WALLY-plic.h).
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

// =============================================================================================
// 1. Reset values (impl: the spec gives no reset values; Wally clears every PLIC register).
//    Nothing is pending because no device raises its interrupt line out of reset.
// =============================================================================================
.irp s, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
    CHKR(PLIC_PRIO+4*\s, 0)
.endr
    CHKR(PLIC_PEND0, 0)
    CHKR(PLIC_PEND1, 0)
    CHKR(PLIC_EN0, 0)
    CHKR(PLIC_EN0+4, 0)
    CHKR(PLIC_EN1, 0)
    CHKR(PLIC_EN1+4, 0)
    CHKR(PLIC_THRESH0, 0)
    CHKR(PLIC_THRESH1, 0)
    CLAIM(0, 0)                         // "zero if there is no pending interrupt" (Interrupt Claim Process)
    CLAIM(1, 0)
    CHKMIP(0)

// =============================================================================================
// 2. Priorities are WARL ("Interrupt Priorities"); all combinations of the variable bits are valid
//    levels.  Wally implements 3 bits (impl), so all ones reads 7 and bit 3 alone reads 0.
// =============================================================================================
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    PRIO \s, 0xFFFFFFFF
    CHKR(PLIC_PRIO+4*\s, 7)
.endr
.irp v, 0,1,2,3,4,5,6,7
    PRIO 1, \v
    CHKR(PLIC_PRIO+4*1, \v)
    PRIO 14, \v
    CHKR(PLIC_PRIO+4*14, \v)
.endr
    PRIO 5, 0x8
    CHKR(PLIC_PRIO+4*5, 0)
    PRIO 5, 0xFFFFFFF8
    CHKR(PLIC_PRIO+4*5, 0)

    // each source keeps its own value: write a pattern to all, then read all
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    PRIO \s, ((\s*3)&7)
.endr
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    CHKR(PLIC_PRIO+4*\s, ((\s*3)&7))
.endr
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    PRIO \s, ((\s^5)&7)
.endr
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    CHKR(PLIC_PRIO+4*\s, ((\s^5)&7))
.endr

// =============================================================================================
// 3. Source 0 does not exist: its priority word is reserved ("base + 0x000000: Reserved (interrupt
//    source 0 does not exist)").  A write must not change any real source; the read returns 0
//    (impl for a reserved word, but it must not be a live register).
// =============================================================================================
    PRIO 0, 0xFFFFFFFF
    CHKR(PLIC_PRIO, 0)
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    CHKR(PLIC_PRIO+4*\s, ((\s^5)&7))
.endr

// =============================================================================================
// 4. Sources above PLIC_NUM_SRC (15-1023 in a 14-source PLIC) do not exist.  Their priority words
//    read 0 (impl: a hardwired-0 WARL priority) and writes to them must not change sources 1-14.
//    Existing sources above 14 (53-source builds) read back 7.
// =============================================================================================
.irp s, 15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,128,1023
    PRIO \s, 0xFFFFFFFF
    CHKR(PLIC_PRIO+4*\s, ((\s <= NSRC) & 1) * 7)
    PRIO \s, 0
.endr
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    CHKR(PLIC_PRIO+4*\s, ((\s^5)&7))
.endr

// =============================================================================================
// 5. Pending bits are read through the pending array and set only by the gateways ("Interrupt
//    Pending Bits"; "Interrupt Gateways"); bit 0 of word 0 is hardwired to 0.  A store to the
//    array must not create a pending interrupt: with every source enabled at priority 7 and
//    threshold 0, nothing becomes claimable and no EIP rises.
// =============================================================================================
.irp s, 1,2,3,4,5,6,7,8,9,10,11,12,13,14
    PRIO \s, 7
.endr
    ENABLE 0, 0xFFFFFFFF
    ENABLE 1, 0xFFFFFFFF
    PW PLIC_PEND0, 0xFFFFFFFF
    PW PLIC_PEND1, 0xFFFFFFFF
    PW PLIC_PEND0+0x7C, 0xFFFFFFFF
    SETTLE
    CHKR(PLIC_PEND0, 0)
    CHKR(PLIC_PEND1, 0)
    CHKR(PLIC_PEND0+8, 0)               // words 2-31: sources 64-1023 do not exist
    CHKR(PLIC_PEND0+0x7C, 0)
    CHKMIP(0)
    CLAIM(0, 0)
    CLAIM(1, 0)

// =============================================================================================
// 6. Enables ("Interrupt Enables"): one bit per source per context; bit 0 of word 0 is hardwired
//    to 0 and bits of nonexistent sources read 0.  Contexts are independent.
// =============================================================================================
    ENABLE 0, 0xFFFFFFFF
    CHKR(PLIC_EN0, ALLSRC)
    ENABLE 1, 0xFFFFFFFF
    CHKR(PLIC_EN1, ALLSRC)
    PW PLIC_EN0+4, 0xFFFFFFFF
    CHKR(PLIC_EN0+4, ALLSRC1)           // sources 32-63: none in a 14-source PLIC
    PW PLIC_EN1+4, 0xFFFFFFFF
    CHKR(PLIC_EN1+4, ALLSRC1)
    PW PLIC_EN0+4, 0
    PW PLIC_EN1+4, 0
    ENABLE 0, 0x00005555
    ENABLE 1, 0x0000AAAA
    CHKR(PLIC_EN0, 0x00005554)
    CHKR(PLIC_EN1, 0x0000AAAA & ALLSRC)
    ENABLE 0, 0
    CHKR(PLIC_EN0, 0)
    CHKR(PLIC_EN1, 0x0000AAAA & ALLSRC)
    ENABLE 0, 0x00005555
    // enable words of nonexistent sources (words 2-31) and contexts (2, 3, 15871)
.irp a, 0x2008, 0x207C, 0x2088, 0x20FC, 0x2100, 0x2180, 0x1F1F80, 0x1F1FFC
    PW \a, 0xFFFFFFFF
    CHKR(\a, 0)
.endr
    CHKR(PLIC_EN0, 0x00005554)
    CHKR(PLIC_EN1, 0x0000AAAA & ALLSRC)

// =============================================================================================
// 7. Thresholds ("Priority Thresholds") are WARL, one per context (3 bits, impl).  Words between
//    the claim/complete registers are reserved; contexts 2 and up do not exist.
// =============================================================================================
    THRESH 0, 0xFFFFFFFF
    CHKR(PLIC_THRESH0, 7)
    THRESH 1, 0xFFFFFFFF
    CHKR(PLIC_THRESH1, 7)
.irp v, 0,1,2,3,4,5,6,7
    THRESH 0, \v
    CHKR(PLIC_THRESH0, \v)
    THRESH 1, (7-\v)
    CHKR(PLIC_THRESH1, (7-\v))
.endr
    THRESH 0, 3
    THRESH 1, 5
    CHKR(PLIC_THRESH0, 3)
    CHKR(PLIC_THRESH1, 5)
    // reserved words of contexts 0 and 1, and threshold/claim of contexts 2, 3 and 15871
.irp a, 0x200008, 0x200FFC, 0x201008, 0x201FFC, 0x202000, 0x202004, 0x203000, 0x3FFF000, 0x3FFF004, 0x3FFFFFC
    PW \a, 0xFFFFFFFF
    CHKR(\a, 0)
.endr
    CHKR(PLIC_THRESH0, 3)
    CHKR(PLIC_THRESH1, 5)

// =============================================================================================
// 8. Aliasing.  The PLIC region is 64 MiB (PLIC_RANGE 0x3FFFFFF, matching the 0x0000000-0x3FFFFFC
//    memory map).  Offsets 0x1000000-0x3FFFFFF hold thresholds and claims of contexts 3584-15871
//    (nonexistent here) or reserved words ("Memory Map"), so offset + 0x1000000*k (k = 1..3) must
//    not reach the real registers at offset.  Reads return 0 (impl); writes leave the real
//    registers unchanged.
// =============================================================================================
.irp k, 1,2,3
    CHKR(0x1000000*\k + PLIC_PRIO+4*3, 0)
    CHKR(0x1000000*\k + PLIC_PRIO+4*10, 0)
    CHKR(0x1000000*\k + PLIC_EN0, 0)
    CHKR(0x1000000*\k + PLIC_EN1, 0)
    CHKR(0x1000000*\k + PLIC_THRESH0, 0)
    CHKR(0x1000000*\k + PLIC_THRESH1, 0)
.endr
.irp k, 1,2,3
    PW 0x1000000*\k + PLIC_PRIO+4*3, 0
    PW 0x1000000*\k + PLIC_EN0, 0
    PW 0x1000000*\k + PLIC_EN1, 0
    PW 0x1000000*\k + PLIC_THRESH0, 0
    PW 0x1000000*\k + PLIC_THRESH1, 0
.endr
    CHKR(PLIC_PRIO+4*3, 7)
    CHKR(PLIC_EN0, 0x00005554)
    CHKR(PLIC_EN1, 0x0000AAAA & ALLSRC)
    CHKR(PLIC_THRESH0, 3)
    CHKR(PLIC_THRESH1, 5)

    QUIESCE
    END_TESTS

PLIC_HELPERS

TEST_STACK_AND_DATA

PLIC_EXPECTED_END
