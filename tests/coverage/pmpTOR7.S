///////////////////////////////////////////
// pmpTOR7.S
//
// Written: David_Harris@hmc.edu
//
// Purpose: Directed coverage test for PMP entry 7 TOR address decoder.
//
//   Target gap: src/mmu/pmpadrdec.sv line 73, focused-expression term
//   TORMatch for PMP entry 7, instance .../ifu/immu/immu/pmp/pmpchecker/pmpadrdecs[7].
//
//   pmpadrdec.sv computes (line 58-60):
//       PAltPMPAdr   = PhysicalAddress < {PMPAdr,2'b00}
//       PAgePMPAdrIn = (cascaded ">= previous entry's PMPAdr")
//       TORMatch     = PAgePMPAdrIn & PAltPMPAdr
//   and line 73 selects Match = (AdrMode==TOR) ? TORMatch : ...
//
//   For a TOR entry i, PAgePMPAdrIn is the cascaded ">= pmpaddr[i-1]" term, so
//   entry 7 matches when  pmpaddr6<<2 <= PA < pmpaddr7<<2.  Entry 7 had only ever
//   been exercised with the checked PA OUTSIDE its TOR range (TORMatch=0).  This
//   test brackets a block of *instruction* memory with pmpaddr6/pmpaddr7 in TOR
//   mode and then fetches/executes instructions whose PA lies inside that range,
//   so the IMMU's pmpadrdecs[7] evaluates TORMatch=1.
//
//   The decoder is combinational and independent of PMP priority: TORMatch[7] is
//   driven for whatever PA the checker is evaluating regardless of which entry
//   wins the priorityonehot.  Entry 0 (set up by WALLY-init-lib.h to TOR RWX over
//   the whole address space) keeps winning priority and granting X, so the fetch
//   succeeds in machine mode while entry 7's TORMatch still toggles to 1.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"

main:
    # ------------------------------------------------------------------
    # Program PMP entry 7 as a TOR region that brackets the executable
    # block labelled [tor_lo, tor_hi).  pmpaddr registers hold addr>>2.
    #   pmpaddr6 = tor_lo >> 2      (lower bound, cascaded into entry 7)
    #   pmpaddr7 = tor_hi >> 2      (upper bound of entry 7's TOR range)
    # ------------------------------------------------------------------
    la t0, tor_lo
    srli t0, t0, 2
    csrw pmpaddr6, t0       # pmpaddr6 = tor_lo>>2  -> entry 7 lower bound

    la t1, tor_hi
    srli t1, t1, 2
    csrw pmpaddr7, t1       # pmpaddr7 = tor_hi>>2  -> entry 7 upper bound

    # ------------------------------------------------------------------
    # Configure pmpcfg entry 7 = TOR (A=01), R/W/X, L (locked).
    # On RV64 pmpcfg0 holds entries 0..7, one byte each; entry 7 = bits[63:56].
    # Byte value = L(1)<<7 | A(01)<<3 | X(1)<<2 | W(1)<<1 | R(1)
    #            = 0x80 | 0x08 | 0x07 = 0x8F.
    # Read-modify-write pmpcfg0 so the lower entries the init lib set up
    # (entry 0 = 0x0F TOR RWX over all space) are preserved.
    # ------------------------------------------------------------------
    li t2, 0x8F
    slli t2, t2, 56         # place in entry-7 byte position [63:56]
    csrr t3, pmpcfg0        # read current pmpcfg0 (preserve entries 0-6)
    or  t3, t3, t2          # OR in entry-7 = TOR RWX L
    csrw pmpcfg0, t3

    # ------------------------------------------------------------------
    # Now execute instructions whose fetch PA is inside [tor_lo, tor_hi).
    # Each fetch drives the IMMU PhysicalAddress through pmpadrdecs[7], where
    #   pmpaddr6<<2 <= PA < pmpaddr7<<2  ==>  TORMatch[7] = 1   (pmpadrdec.sv:60,73)
    # Entry 0 still wins priority and grants X, so the fetch is allowed.
    # ------------------------------------------------------------------
.align 3
tor_lo:                     # lower bound of TOR region (PMP-bracketed code)
    nop
    nop
    addi t4, x0, 1
    addi t4, t4, 1
    nop
    nop
.align 3
tor_hi:                     # upper bound: addresses >= here are NOT in entry 7's range

    j done
