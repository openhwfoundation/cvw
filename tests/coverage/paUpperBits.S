///////////////////////////////////////////
// paUpperBits.S
//
// Written: David_Harris@hmc.edu 11 October 2026
//
// Purpose: With translation off (M mode, or S mode with satp.MODE = Bare), an address is a physical address,
//          so bits XLEN-1:PA_BITS (63:56 on RV64) must be zero.  An address with any of them set is outside
//          the physical address space, not an alias of the low 56 bits, so every access to it raises an
//          access fault of the access type with mtval = the full address.  Covers loads, stores, AMOs, LR/SC,
//          FP loads and stores, cache-block operations, and instruction fetch, and checks that a faulting
//          store does not write the aliased location.  Self-checking (WALLY-selfcheck.h).
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

.option norvc                           // every access is 4 bytes, so the fault handler skips 4

#define DATAVAL 0x0123456789ABCDEF

// Run one access that must fault, then check mcause (s10) and mtval (s11) against the expected cause and s0.
.macro FAULTS cause, index, insn:vararg
    li s10, 0
    li s11, 0
    \insn
    li t2, \cause
    SC_CHECK_EQ s10, t2, \index
    SC_CHECK_EQ_ADR s11, s0, s0, \index + 0x80
.endm

// All accesses at the bad address s0, in the current privilege mode
.macro ALLACCESSES base
    FAULTS 5, \base + 0,  ld t3, 0(s0)
    FAULTS 5, \base + 1,  lw t3, 0(s0)
    FAULTS 5, \base + 2,  lbu t3, 0(s0)
    FAULTS 7, \base + 3,  sd s1, 0(s0)
    FAULTS 7, \base + 4,  sh s1, 0(s0)
    FAULTS 7, \base + 5,  amoadd.d t3, s1, (s0)
    FAULTS 7, \base + 6,  amoswap.w t3, s1, (s0)
    FAULTS 5, \base + 7,  lr.d t3, (s0)
    FAULTS 7, \base + 8,  sc.d t3, s1, (s0)
    FAULTS 5, \base + 9,  fld ft0, 0(s0)
    FAULTS 7, \base + 10, fsw ft0, 0(s0)
    FAULTS 1, \base + 11, jalr ra, 0(s0)
.endm

main:
    la t0, pafault
    csrw mtvec, t0
    li t0, 0x2000
    csrs mstatus, t0                    // mstatus.FS = Initial so FP loads and stores execute
    li t0, 0xF0
    csrs menvcfg, t0                    // CBIE = 11, CBCFE = 1, CBZE = 1: S mode may execute cbo.*
    la s2, data
    li s1, DATAVAL
    sd s1, 0(s2)                        // aliased location starts with DATAVAL
    li s1, -1                           // value the faulting stores try to write

    // M mode: bit 56 (lowest bit above PA_BITS), bit 63, and all of 63:56, each over a RAM address
    li s3, 1
    slli s3, s3, 56
    or s0, s2, s3
    ALLACCESSES 0x00
    FAULTS 7, 0x10, cbo.zero 0(s0)
    FAULTS 7, 0x11, cbo.clean 0(s0)
    FAULTS 7, 0x12, cbo.flush 0(s0)
    FAULTS 7, 0x13, cbo.inval 0(s0)
    li s3, 1
    slli s3, s3, 63
    or s0, s2, s3
    ALLACCESSES 0x20
    li s3, 0xFF
    slli s3, s3, 56
    or s0, s2, s3
    ALLACCESSES 0x30

    // S mode with satp.MODE = Bare
    csrw satp, zero
    li s3, 1
    slli s3, s3, 60
    or s0, s2, s3
    li a0, 1
    ecall                               // to S mode
    ALLACCESSES 0x40
    FAULTS 7, 0x50, cbo.zero 0(s0)
    FAULTS 7, 0x51, cbo.clean 0(s0)
    li a0, 3
    ecall                               // back to M mode

    // M mode with mstatus.MPRV = 1 and MPP = S: data accesses use S mode with satp.MODE = Bare
    // (the trap sets MPP = M and mret leaves MPP = U, so set MPP before each access)
    li t0, 0x20800                      // MPRV, MPP = 01
    csrs mstatus, t0
    FAULTS 5, 0x60, ld t3, 0(s0)
    li t0, 0x20800
    csrs mstatus, t0
    FAULTS 7, 0x61, sd s1, 0(s0)
    li t0, 0x20000
    csrc mstatus, t0

    // No faulting store wrote the aliased location, and it can still be read at its real address
    ld t3, 0(s2)
    li t2, DATAVAL
    SC_CHECK_EQ t3, t2, 0x70

    SC_PASS
    j done

// Access faults (mcause 1, 5, 7): record mcause in s10 and mtval in s11, then resume after the faulting
// instruction (all are 4 bytes) or, for a fetch, at the return address of the jalr.  Everything else goes to
// sc_trap_handler, which passes ecalls to the WALLY-init-lib.h handler and fails the test on any other trap.
.align 4
pafault:
    csrr s9, mcause
    addi s9, s9, -1
    beqz s9, pafetch
    addi s9, s9, -4
    beqz s9, padata
    addi s9, s9, -2
    bnez s9, sc_trap_handler
padata:
    csrr s10, mcause
    csrr s11, mtval
    csrr s9, mepc
    addi s9, s9, 4
    csrw mepc, s9
    mret
pafetch:
    li s10, 1
    csrr s11, mtval
    csrw mepc, ra
    mret

.data
.align 12
data:
    .dword 0
