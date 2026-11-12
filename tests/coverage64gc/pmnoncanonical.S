///////////////////////////////////////////
// pmnoncanonical.S
//
// Written: David_Harris@hmc.edu 7 November 2026
//
// Purpose: Sv39 canonical-address check with pointer masking (PMLEN 7).  With masking, bits 63:57 are
//          ignored and bits 56:39 must all equal bit 38.  Each access below has bits 56:47 consistent but
//          bits 46:38 mixed, so it must take a page fault without walking the page table, and mtval must
//          be the masked address (bits 63:57 replaced by copies of bit 56).
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

// TRY_MPRV insn, adr, cause, tval, idx: from M mode with mstatus.MPRV=1 and MPP=S, so the access is
// translated and pointer masked as in S mode, execute insn with s0 = adr and expect a trap with
// mcause = cause and mtval = tval.  pm_trap_handler records mcause in s8 and mtval in s9 and resumes at
// s11.  MPRV is cleared before the checks so that a failure record is not translated.
.macro TRY_MPRV insn, adr, cause, tval, idx
    li s0, \adr
    li s8, -1
    li s9, -1
    la s11, 1f
    li t0, 0x1000
    csrc mstatus, t0
    li t0, 0x20800                  # MPRV, MPP = S
    csrs mstatus, t0
    \insn
1:
    li t0, 0x20000
    csrc mstatus, t0
    li t2, \cause
    SC_CHECK_EQ s8, t2, \idx
    li t2, \tval
    SC_CHECK_EQ s9, t2, \idx+1
.endm

main:
    # PMP: allow everything
    li t0, -1
    csrw pmpaddr0, t0
    li t0, 0x1F
    csrw pmpcfg0, t0
    # menvcfg.PMM = 10: pointer masking with PMLEN 7 in S mode
    li t0, 2
    slli t0, t0, 32
    csrs menvcfg, t0
    # Sv39.  These addresses fault before any page table access, so the root page is never read.
    la t0, pt_root
    srli t0, t0, 12
    li t1, 8
    slli t1, t1, 60
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
    la t0, pm_trap_handler
    csrw mtvec, t0

    # Bits 56:47 all 0, bits 46:38 mixed (bit 38 set); bits 63:57 = 0x2D are masked off
    TRY_MPRV "ld s1, 0(s0)",  0x5A00004000000123, 13, 0x0000004000000123, 0x10
    TRY_MPRV "sd s1, 0(s0)",  0x5A00004000000123, 15, 0x0000004000000123, 0x12
    # Bits 56:47 all 1, bits 46:38 mixed (bit 38 clear); bits 63:57 = 0x15 are masked off
    TRY_MPRV "ld s1, 0(s0)",  0x2BFFFF8000000456, 13, 0xFFFFFF8000000456, 0x14
    TRY_MPRV "sd s1, 0(s0)",  0x2BFFFF8000000456, 15, 0xFFFFFF8000000456, 0x16
    SC_PASS
    j done

// Record mcause/mtval and resume at s11; forward interrupts and ecalls to the WALLY-init-lib.h handler
.align 4
pm_trap_handler:
    csrr s8, mcause
    bltz s8, pm_forward
    addi s10, s8, -8
    beqz s10, pm_forward            # ecall from U
    addi s10, s8, -9
    beqz s10, pm_forward            # ecall from S
    addi s10, s8, -11
    beqz s10, pm_forward            # ecall from M
    csrr s9, mtval
    csrw mepc, s11
    mret
pm_forward:
    j trap_handler

.data
.align 12
pt_root:
    .fill 512, 8, 0
