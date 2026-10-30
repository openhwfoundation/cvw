///////////////////////////////////////////
// spillfaultdefer.S
//
// Written: david_harris@hmc.edu 14 October 2026
//
// Purpose: A page-crossing misaligned store whose first half faults must take the fault and
//          write nothing.  Before the align fix, a committed I$ fill deferring the trap let the
//          spill FSM advance to the second-half address; the fault, recomputed combinationally,
//          vanished, so the store retired with no trap, the second half written and the first not.
//          The failing interleaving depends on where the sd sits in its I$ line, so sweep it
//          across a line with cold I$ (fence.i) and cold DTLB (sfence.vma) each trial.
//          Without the fix (main at 9f672c914), trial 22, with the sd at byte 0x34 of its 64-byte
//          I$ line, loses the fault, alone or in the full sweep, and fails check 22.  If a timing
//          change makes trial 22 pass without the fix, this test no longer reaches the bug.
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

.macro TRIAL n
    .align 6
    fence.i                   // cold I$: the fetches around the sd miss
    sfence.vma                // cold DTLB: the sd replays after a walk
    .rept \n
    c.nop
    .endr
    sd s3, 0(s2)              // first half in the read-only page: store page fault, nothing written
    addi s9, s9, 1
    SC_CHECK_EQ s8, s9, \n    // exactly one store page fault per trial
.endm

main:
    la t0, faulthandler
    csrw mtvec, t0            // the faulting sd must be skipped, not re-executed
    // Sv39: VPN2=2 identity RWX gigapage (in pt_root), VPN2=3 -> pt_l1
    la t0, pt_l1
    srli t0, t0, 12
    slli t0, t0, 10
    ori t0, t0, 1
    la t1, pt_root
    sd t0, 24(t1)
    srli t1, t1, 12
    li t2, 8
    slli t2, t2, 60
    or t1, t1, t2
    csrw satp, t1
    sfence.vma
    li s2, 0xC01FFFFC         // last 4B of the read-only megapage; crosses into the RW megapage
    li s3, 0x1122334455667788
    li s8, 0                  // store page faults taken
    li s9, 0                  // trials run
    li a0, 1
    ecall                     // to S mode

    // sentinels under both halves of the store, via the writable alias of the read-only page
    li t2, 0xC05FFFFC         // alias of PA 0x801FFFFC (first half)
    li t3, 0xAA55AA55
    sw t3, 0(t2)
    li t4, 0xC0200000         // second half
    li t5, 0x5A5AC3C3
    sw t5, 0(t4)
    fence

    .irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    TRIAL \n
    .endr

    // neither half of any faulted store may have reached memory
    li t2, 0xC05FFFFC
    lwu t3, 0(t2)             // lwu: the li constants are positive
    li t4, 0xAA55AA55
    SC_CHECK_EQ t3, t4, 100
    li t2, 0xC0200000
    lwu t3, 0(t2)
    li t4, 0x5A5AC3C3
    SC_CHECK_EQ t3, t4, 101

    SC_PASS
    j done

.align 4
faulthandler:
    csrr t0, mcause
    li t1, 15
    beq t0, t1, 1f
    j trap_handler            // ecalls and anything unexpected go to the library handler
1:  addi s8, s8, 1
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0             // skip the faulting sd
    mret

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF         // VPN2=2: identity gigapage, V R W X A D
    .dword 0                  // VPN2=3: filled in at run time
    .fill 508, 8, 0
pt_l1:
    .dword 0x200000C3         // 0xC0000000 -> PA 0x80000000 megapage, V R A D (read-only)
    .dword 0x200800C7         // 0xC0200000 -> PA 0x80200000 megapage, V R W A D
    .dword 0x200000C7         // 0xC0400000 -> PA 0x80000000 megapage, RW alias for the sentinels
    .fill 509, 8, 0
