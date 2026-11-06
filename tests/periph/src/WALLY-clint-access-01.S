///////////////////////////////////////////
// WALLY-clint-access-01.S
//
// Purpose: Accesses to the CLINT that the platform does not support must trap without side effects:
//          misaligned loads and stores (the CLINT is an I/O region, so an address-misaligned or an
//          access-fault exception is allowed [PRIV, "Misaligned accesses"]), AMOs and LR (the region
//          does not support atomics: access fault [PRIV, PMA "Atomicity PMAs"]), and instruction fetch
//          (not executable: instruction access fault).  A trapping store must not change the register.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"
#include "WALLY-clint.h"

// Append 1 if s7 (mcause of the last trap, or -1 if none) is \c1 or \c2, else 0; then reset s7.
.macro CHK_CAUSE c1, c2
    li t3, \c1
    li t2, 1
    beq s7, t3, 9f
    li t3, \c2
    beq s7, t3, 9f
    li t2, 0
9:
    SIGR t2
    li s7, -1
.endm

INIT_TESTS

TRAP_HANDLER m

    li s0, CLINT_MSIP
    li s1, CLINT_MTIMECMP
    li s2, CLINT_MTIME
    li s7, -1
    la t3, access_trap
    csrrw s8, mtvec, t3
    li t3, 1
    sw t3, 0(s0)                    // msip = 1 (machine interrupts are disabled)
    SETCMP 0x01234567, 0x89ABCDEF

// ---------------- Misaligned loads: address-misaligned (4) or load access fault (5) ----------------
    lw t4, 2(s1)
    CHK_CAUSE 4, 5                  // 1
    lh t4, 1(s0)
    CHK_CAUSE 4, 5                  // 1
#if __riscv_xlen == 64
    ld t4, 4(s2)
#else
    lw t4, 1(s2)
#endif
    CHK_CAUSE 4, 5                  // 1

// ---------------- Misaligned stores: address-misaligned (6) or store access fault (7); no write ----------------
    li t4, 0xDEADBEEF
    sw t4, 2(s1)
    CHK_CAUSE 6, 7                  // 1
    CHKW 0, s1                      // 0x89ABCDEF
    CHKW 4, s1                      // 0x01234567
    sh zero, 1(s0)
    CHK_CAUSE 6, 7                  // 1
    sw zero, 2(s0)
    CHK_CAUSE 6, 7                  // 1
    CHKW 0, s0                      // 1: msip unchanged
#if __riscv_xlen == 64
    sd t4, 4(s1)
#else
    sh t4, 3(s1)
#endif
    CHK_CAUSE 6, 7                  // 1
    CHKW 0, s1                      // 0x89ABCDEF
    CHKW 4, s1                      // 0x01234567

// ---------------- AMOs and LR: the CLINT does not support atomics ----------------
.option push
.option arch, +a
    amoswap.w t4, zero, (s0)
    CHK_CAUSE 7, 7                  // 1
    CHKW 0, s0                      // 1: msip unchanged
    li t5, 0x10
    amoadd.w t4, t5, (s1)
    CHK_CAUSE 7, 7                  // 1
    CHKW 0, s1                      // 0x89ABCDEF
    lr.w t4, (s0)
    CHK_CAUSE 5, 7                  // 1
.option pop

// ---------------- Instruction fetch: instruction access fault (1) ----------------
    jalr ra, 0(s0)
    CHK_CAUSE 1, 1                  // 1
    li t4, CLINT + 0x4000
    jalr ra, 0(t4)
    CHK_CAUSE 1, 1                  // 1
    CHKW 0, s0                      // 1: msip unchanged

    sw zero, 0(s0)
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF
    csrw mtvec, s8

END_TESTS

CLINT_HELPERS

// access_trap: records mcause in s7; returns to ra after an instruction access fault, else skips the
// faulting instruction.  Uses t2.
.align 6
access_trap:
    csrr s7, mcause
    li t2, 1
    beq s7, t2, 1f
    csrr t2, mepc
    addi t2, t2, 4
    csrw mepc, t2
    mret
1:
    csrw mepc, ra
    mret

TEST_STACK_AND_DATA

.align REGSHIFT
expected_signature:
WORD 1, 1, 1                                            // 0: misaligned loads trap
WORD 1, 0x89ABCDEF, 0x01234567                          // 3: misaligned sw to mtimecmp
WORD 1, 1, 1                                            // 6: misaligned stores to msip
WORD 1, 0x89ABCDEF, 0x01234567                          // 9: misaligned store across the mtimecmp halves
WORD 1, 1, 1, 0x89ABCDEF, 1                             // 12: AMOs, LR
WORD 1, 1, 1                                            // 17: fetch
WORD 0x0B                                               // 20: ecall from test termination
expected_signature_end:
