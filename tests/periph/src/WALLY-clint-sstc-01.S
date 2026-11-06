///////////////////////////////////////////
// WALLY-clint-sstc-01.S
//
// Purpose: Sstc interplay with the CLINT: with menvcfg.STCE = 1, mip.STIP = (time >= stimecmp) as
//          an unsigned compare against the memory-mapped mtime, follows writes to mtime, is
//          read-only in mip, and is independent of mtimecmp/MTIP.  With STCE = 0, STIP is the
//          software-writable bit again.  Requires a configuration with Sstc (rv32gc, rv64gc).
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

// stimecmp = {\hi, \lo} (RV32: lo = -1, hi, lo, as for mtimecmp)
.macro SETSCMP hi, lo
#if __riscv_xlen == 64
    li t3, \hi
    slli t3, t3, 32
    li t4, \lo
    ZEXT32 t4
    or t3, t3, t4
    csrw CSR_STIMECMP, t3
#else
    li t3, -1
    csrw CSR_STIMECMP, t3
    li t3, \hi
    csrw CSR_STIMECMPH, t3
    li t3, \lo
    csrw CSR_STIMECMP, t3
#endif
.endm

INIT_TESTS

TRAP_HANDLER m

    li s0, CLINT_MSIP
    li s1, CLINT_MTIMECMP
    li s2, CLINT_MTIME
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF
    SETSCMP 0xFFFFFFFF, 0xFFFFFFFF
#if __riscv_xlen == 64
    li t3, 1
    slli t3, t3, 63
    csrs CSR_MENVCFG, t3            // STCE
#else
    li t3, 0x80000000
    csrs CSR_MENVCFGH, t3           // STCE
#endif

// ---------------- STCE = 1: STIP = time >= stimecmp [Sstc] ----------------
    CHK_STIP                        // 0: stimecmp = all ones
    SETSCMP 0, 0
    CHK_STIP                        // 1
    CHK_MTIP                        // 0: independent of mtimecmp
    SETSCMP 0xFFFFFFFF, 0xFFFFFFFF
    CHK_STIP                        // 0
    li t3, MIP_STIP
    csrs mip, t3
    CHK_STIP                        // 0: read-only while STCE = 1
// STIP rises as mtime counts past stimecmp
    SETSCMP 7, 0x1000
    SETTIME 7, 0
    CHK_STIP                        // 0
    li t4, 200000
1:
    csrr t3, mip
    andi t3, t3, MIP_STIP
    bnez t3, 2f
    addi t4, t4, -1
    bnez t4, 1b
2:
    CHK_STIP                        // 1
    lw t4, 0(s2)
    ZEXT32 t4
    li t3, 0x1000
    sltu t2, t4, t3
    SIGR t2                         // 0: mtime >= stimecmp by then
// Writing mtime below stimecmp clears STIP
    SETTIME 6, 0
    CHK_STIP                        // 0
// Unsigned compare
    SETSCMP 0x80000000, 0
    SETTIME 0x7FFFFFFF, 0
    CHK_STIP                        // 0
    SETTIME 0x80000000, 0
    CHK_STIP                        // 1
    CHK_MTIP                        // 0
// stimecmp reads back
    SETSCMP 0x01234567, 0x89ABCDEF
    csrr t2, CSR_STIMECMP
    SIG32 t2                        // 0x89ABCDEF
#if __riscv_xlen == 64
    csrr t2, CSR_STIMECMP
    srli t2, t2, 32
#else
    csrr t2, CSR_STIMECMPH
#endif
    SIG32 t2                        // 0x01234567

// ---------------- STCE = 0: STIP is the writable mip bit again ----------------
    SETSCMP 0, 0                    // time >= stimecmp
#if __riscv_xlen == 64
    li t3, 1
    slli t3, t3, 63
    csrc CSR_MENVCFG, t3
#else
    li t3, 0x80000000
    csrc CSR_MENVCFGH, t3
#endif
    li t3, MIP_STIP
    csrc mip, t3
    CHK_STIP                        // 0
    csrs mip, t3
    CHK_STIP                        // 1
    csrc mip, t3
    CHK_STIP                        // 0
    SETSCMP 0xFFFFFFFF, 0xFFFFFFFF
    SETTIME 0, 0

END_TESTS

CLINT_HELPERS

TEST_STACK_AND_DATA

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each; 32-bit values are zero extended on RV64).
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0, 1, 0, 0, 0                                      // 0: stimecmp all ones / 0, MTIP, STIP read-only
WORD 0, 1, 0                                            // 5: rising as mtime counts
WORD 0                                                  // 8: mtime write clears
WORD 0, 1, 0                                            // 9: unsigned compare
WORD 0x89ABCDEF, 0x01234567                             // 12: stimecmp readback
WORD 0, 1, 0                                            // 14: STCE = 0
WORD 0x0B                                               // 17: ecall from test termination
expected_signature_end:
