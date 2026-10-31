///////////////////////////////////////////
// bootromfetch.S
//
// Written: David_Harris@hmc.edu 30 October 2026
//
// Purpose: rv32gc: an instruction fetch from the boot ROM (0x1000), so the IFU's PMA checker decodes the
//          boot ROM region for an execute access (bootromdec Match, Supported, AccessValid, SizeValid), in
//          a region where atomics are not allowed.  The testbench loads nothing into the boot ROM for
//          these tests, so the fetch must not execute: PMP entry 0 makes the boot ROM page readable but
//          not executable, entry 1 allows everything else, and an mret to 0x1000 in U mode takes an
//          instruction access fault on the fetch.  This test's own handler records the trap and returns
//          to M mode.
//          Self-checking: mcause = 1 (failure index 1), mepc = 0x1000 (2), mtval = 0x1000 (3).
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

#define BOOTROM  0x00001000

main:
    // PMP entry 0: NAPOT 4 KiB at the boot ROM, R only; entry 1: NAPOT over all 32-bit addresses, RWX
    li t0, (BOOTROM | 0x7FF) >> 2
    csrw pmpaddr0, t0
    li t0, 0x1FFFFFFF
    csrw pmpaddr1, t0
    li t0, 0x1F19
    csrw pmpcfg0, t0

    la t0, rom_trap
    csrw mtvec, t0
    li t0, 0x1800
    csrc mstatus, t0                    // mstatus.MPP = U
    li t0, BOOTROM
    csrw mepc, t0
    mret                                // fetch 0x1000 in U mode: instruction access fault

resume:
    la t0, trap_handler                 // back to the library handler
    csrw mtvec, t0
    li t0, 1
    SC_CHECK_EQ s1, t0, 1
    li t0, BOOTROM
    SC_CHECK_EQ s2, t0, 2
    SC_CHECK_EQ s3, t0, 3
    SC_PASS
    j done

// Record the trap and return to resume in M mode
.align 2
rom_trap:
    csrr s1, mcause
    csrr s2, mepc
    csrr s3, mtval
    li t0, 0x1800
    csrs mstatus, t0                    // mstatus.MPP = M
    la t0, resume
    csrw mepc, t0
    mret
