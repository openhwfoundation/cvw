///////////////////////////////////////////
// pmplock.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: PMP lock cascade on rv32gc (16 entries, 4 per pmpcfg CSR).  A locked entry ignores writes to
//          its pmpcfg byte and pmpaddr, and a locked TOR entry i also locks pmpaddr[i-1], which is its
//          region's lower bound (csrm.sv ADDRLocked).  Locks are sticky until reset, so the test locks
//          entries 15 down to 2 as TOR in order: when entry i is locked, entry i-1 is still unlocked,
//          which exercises ADDRLocked[i-1] = L[i-1] | (L[i] & A[i] == TOR) with only the cascade term
//          true.  Entry 15 is first made TOR while unlocked, when pmpaddr14 must still be writable.
//
//          Entry 0 is the unlocked TOR RWX entry from WALLY-init-lib.h that matches every address, so it
//          is always the first match, and the locked entries (TOR, no permissions) never deny an access.
//
//          Checks: before entry i is locked, pmpaddr[i-1] accepts a write (failure index 100 + i); after,
//          the pmpcfg CSR reads back the locked bytes and ignores the bytes of entries locked earlier
//          (200 + i), and pmpaddr[i] (300 + i) and pmpaddr[i-1] (400 + i) ignore writes.  Entry 15 as
//          unlocked TOR: 1-2.  SC_STRICT_TRAPS fails the test on any access fault.
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

.equ PMPCFG0,  0x3A0
.equ PMPADDR0, 0x3B0

// Initial pmpaddr value of entry i (a multiple of 2^PMP_G words, so TOR/OFF read back unchanged)
#define ADDRVAL(i) (0x100 * (i))

// CHECK_CSRN csrnum, expected, index: fail with index unless CSR csrnum reads expected
.macro CHECK_CSRN csrnum, expected, index
    csrr a1, \csrnum
    li a2, \expected
    SC_CHECK_EQ a1, a2, \index
.endm

// LOCK_STEP i, cfgval, expected: lock entry i (2 <= i <= 15) as TOR with no permissions by writing
// cfgval to pmpcfg(i/4), whose other bytes are 0 except entry 0's TOR RWX byte in pmpcfg0, and expect
// the CSR to read expected (the locked bytes of entries i and above).
.macro LOCK_STEP i, cfgval, expected
    // pmpaddr[i-1] is writable while entry i is OFF (or unlocked) and entry i-1 is unlocked
    li t2, 0x5000 + ADDRVAL(\i)
    csrw PMPADDR0 + \i - 1, t2
    csrr a1, PMPADDR0 + \i - 1
    SC_CHECK_EQ a1, t2, 100 + \i
    li t2, ADDRVAL(\i - 1)
    csrw PMPADDR0 + \i - 1, t2          // restore
    // lock entry i
    li t2, \cfgval
    csrw PMPCFG0 + \i / 4, t2
    CHECK_CSRN PMPCFG0 + \i / 4, \expected, 200 + \i
    // pmpaddr[i] is locked by its own L bit, and pmpaddr[i-1] by entry i's L bit and TOR mode
    li t2, 0x7700
    csrw PMPADDR0 + \i, t2
    CHECK_CSRN PMPADDR0 + \i, ADDRVAL(\i), 300 + \i
    csrw PMPADDR0 + \i - 1, t2
    CHECK_CSRN PMPADDR0 + \i - 1, ADDRVAL(\i - 1), 400 + \i
.endm

main:
    SC_STRICT_TRAPS

    // pmpaddr1-15 get distinct values; entries 1-15 are OFF, so these regions are unused
    .set i, 1
    .rept 15
    li t0, ADDRVAL(i)
    csrw PMPADDR0 + i, t0
    .set i, i+1
    .endr

    // Entry 15 as TOR but unlocked: pmpaddr14 is still writable (ADDRLocked[14] = 0 with A[15] = TOR)
    li t0, 0x08000000
    csrw pmpcfg3, t0
    CHECK_CSRN pmpcfg3, 0x08000000, 1
    li t2, 0x6600
    csrw pmpaddr14, t2
    csrr a1, pmpaddr14
    SC_CHECK_EQ a1, t2, 2
    li t2, ADDRVAL(14)
    csrw pmpaddr14, t2

    // Lock entries 15 down to 2
    LOCK_STEP 15, 0x88000000, 0x88000000
    LOCK_STEP 14, 0x00880000, 0x88880000
    LOCK_STEP 13, 0x00008800, 0x88888800
    LOCK_STEP 12, 0x00000088, 0x88888888
    LOCK_STEP 11, 0x88000000, 0x88000000
    LOCK_STEP 10, 0x00880000, 0x88880000
    LOCK_STEP  9, 0x00008800, 0x88888800
    LOCK_STEP  8, 0x00000088, 0x88888888
    LOCK_STEP  7, 0x88000000, 0x88000000
    LOCK_STEP  6, 0x00880000, 0x88880000
    LOCK_STEP  5, 0x00008800, 0x88888800
    LOCK_STEP  4, 0x00000088, 0x88888888
    LOCK_STEP  3, 0x8800000F, 0x8800000F
    LOCK_STEP  2, 0x0088000F, 0x8888000F

    // Locked bytes ignore a write of all ones; entries 0 and 1 are unlocked and take theirs
    // (entry 1 = 0x00: OFF; entry 0 keeps TOR RWX)
    li t0, -1
    csrw pmpcfg3, t0
    CHECK_CSRN pmpcfg3, 0x88888888, 3
    li t0, 0x0000000F
    csrw pmpcfg0, t0
    CHECK_CSRN pmpcfg0, 0x8888000F, 4
    // pmpaddr0 is still writable: entry 1 is unlocked (and OFF)
    li t2, 0xFFFFFFFF
    csrw pmpaddr0, t2
    csrr a1, pmpaddr0
    li t2, 0xFFFFFFF0                   // TOR with G = 4: pmpaddr[3:0] read as zero
    SC_CHECK_EQ a1, t2, 5

    // Memory still works in M mode through entry 0
    la t0, scratch
    li t1, 0x1234
    sw t1, 0(t0)
    lw t2, 0(t0)
    SC_CHECK_EQ t2, t1, 6

    SC_PASS
    j done

.section .data
.align 4
scratch:
    .word 0
