///////////////////////////////////////////
// deferredexc.S
//
// Written: David_Harris@hmc.edu 10/5/26
//
// Purpose: Demonstrate that a synchronous store page fault deferred by TrapM's ~CommittedF term
//          (trap.sv, issue #412) does not squash the faulting store's own LSU access.  An S-mode
//          store to a read-only page, whose DTLB entry and D$ line are cold, is issued while an
//          I$ line fill holds CommittedF=1.  After the (D$-resident) page-table walk the store
//          page-faults, but the deferred trap leaves the access unflushed, so the store's D$ miss
//          fill merges the store data into the line and mutates the read-only page.  The nop sweep
//          aligns the fetch window so one pass starts the I$ fill exactly as the store enters M.
//          With the fix the read-only page is never written.
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

// Physical/virtual constants
.equ TARGET_PA,   0x86000000        // RAM location mapped read-only through the Sv39 gigapage below
.equ RO_VA,       0x106000000       // VPN2=4 gigapage, read-only, offset 0x06000000 -> PA 0x86000000
.equ VGOOD,       0xAAAAAAAA        // value preloaded into the read-only location
.equ VBAD,        0x55555555        // value the faulting store attempts to write

// One reproduction attempt.  \k 4-byte nops shift the faulting store within its 64-byte I$ line so
// that on some pass the next (freshly cold) line crosses into the fetch stage exactly as the store
// enters M, starting an I$ fill that holds CommittedF=1 while the store's own D$ miss fills+merges.
// Registers: s0=identity VA of target, s1=read-only VA, s6=VBAD.
.macro ATTEMPT k, idx
    li s5, VGOOD
    sw s5, 0(s0)               // preload read-only location (via identity VA): good value, line warm
                               //   in the D$ so the faulting cbo.zero below HITS and zeroes in-place
                               //   (no bus needed, so the write is not serialized behind the I$ fill)
    sfence.vma                 // cold DTLB; the gigapage PTE stays warm in the D$ so the walk hits
                               //   quickly and the cbo.zero faults while the I$ fill is still busy
    fence.i                    // cold I$: the next fetches miss and drive a line fill
    .option push
    .option norvc              // 4-byte instructions so the line layout is exact
    .option norelax            // keep the linker from relaxing away the alignment padding
    .balign 64                 // start the faulting op's line on an I$ line boundary
    .rept \k
        nop
    .endr
    cbo.zero (s1)              // cbo.zero to read-only page: must page fault and leave memory unchanged
    .rept (15 - \k)            // fill the rest of the 64-byte line (k nops + op + these = 16 words)
        nop
    .endr
    // the read-back now starts a fresh (cold) 64-byte I$ line
    lwu s4, 0(s0)              // read the target back through the identity mapping (zero-extended)
    li s5, VGOOD
    .option pop
    SC_CHECK_EQ s4, s5, \idx   // fail if the deferred-fault cbo.zero mutated the read-only page
.endm

main:
    // Enable S-mode cache-block flush/invalidate (menvcfg.CBZE/CBCFE/CBIE = 1/1/11).
    li t0, 0xF0
    csrs menvcfg, t0

    // Read-only gigapage PTE: VPN2=4 -> PA 0x80000000 base, V R A D (W=0 -> store faults).
    la t1, pt_root
    li t0, 0x200000C3
    sd t0, 32(t1)              // pt_root[4]

    // Turn on Sv39 translation.
    srli t1, t1, 12
    li t0, 8
    slli t0, t0, 60
    or t1, t1, t0
    csrw satp, t1
    sfence.vma

    // Persistent registers used by the sweep.
    li s0, TARGET_PA           // identity VA of the target (gigapage VPN2=2 maps 0x8xxxxxxx)
    li s1, RO_VA               // read-only VA that faults on a store
    li s6, VBAD

    li a0, 1
    ecall                      // enter S mode; the sweep runs translated

    // Sweep the store's offset within its I$ line (0..15 instructions) so the fetch window aligns.
    .set n, 0
    .rept 16
        ATTEMPT n, (n+1)
        .set n, n+1
    .endr

    li a0, 3
    ecall                      // back to M mode
    SC_PASS
    j done

.data
.align 12
pt_root:
    .dword 0, 0
    .dword 0x200000CF           // VPN2=2: identity gigapage 0x80000000, V R W X A D
    .dword 0                    // VPN2=3: unused
    .dword 0                    // VPN2=4: read-only gigapage, filled at run time
    .fill 507, 8, 0
