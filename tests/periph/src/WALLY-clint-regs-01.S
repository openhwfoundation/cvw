///////////////////////////////////////////
// WALLY-clint-regs-01.S
//
// Purpose: CLINT register behavior: reset values, MSIP writable bits, byte/halfword/word/doubleword
//          accesses to MSIP, MTIMECMP, and MTIME (partial writes change only the bytes written),
//          the slots of other harts, and unmapped offsets.  Expected values follow the ACLINT and
//          privileged specifications (see WALLY-clint.h).
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

INIT_TESTS

TRAP_HANDLER m

    li s0, CLINT_MSIP
    li s1, CLINT_MTIMECMP
    li s2, CLINT_MTIME

// ---------------- Reset [ACLINT 2.2, 3.2]: MSIP = 0, MTIME = 0 (and has counted only a little) ----------------
// TRAP_HANDLER set mtimecmp to at least 0xFFFFFFFF, so MTIP is clear.
    CHKW 0, s0                      // msip
    CHK_MSIP
    jal ra, clint_read_mtime
    SIG32 a1                        // mtime[63:32]
    li t3, 0x100000
    SIG_LTU a0, t3                  // mtime[31:0] < 0x100000
    CHK_MTIP

// ---------------- MSIP: 32-bit WARL, bits 31:1 wired to zero [ACLINT 3.2] ----------------
    li t3, 1
    sw t3, 0(s0)
    CHKW 0, s0                      // 1
    CHK_MSIP                        // 1
    li t3, -1
    sw t3, 0(s0)
    CHKW 0, s0                      // 1: upper bits read zero
    li t3, 0xFFFFFFFE
    sw t3, 0(s0)
    CHKW 0, s0                      // 0
    CHK_MSIP                        // 0
    li t3, 0x80000001
    sw t3, 0(s0)
    CHKW 0, s0                      // 1
    li t3, 2
    sw t3, 0(s0)
    CHKW 0, s0                      // 0
    li t3, 1
    sw t3, 0(s0)
    CHKB 0, s0                      // 1
    CHKB 1, s0                      // 0
    CHKB 2, s0                      // 0
    CHKB 3, s0                      // 0
    CHKH 0, s0                      // 1
    CHKH 2, s0                      // 0

// ---------------- MSIP byte and halfword stores: only the bytes written change ----------------
    sw zero, 0(s0)
    li t3, 1
    sb t3, 0(s0)
    CHKW 0, s0                      // 1
    sb zero, 0(s0)
    CHKW 0, s0                      // 0
    li t3, 0xFF
    sb t3, 0(s0)
    CHKW 0, s0                      // 1
    li t3, 0xFE
    sb t3, 0(s0)
    CHKW 0, s0                      // 0
// Stores that do not cover byte 0 must leave MSIP clear ...
    li t3, 1
    sb t3, 1(s0)
    CHKW 0, s0                      // 0
    sw zero, 0(s0)
    li t3, 1
    sb t3, 2(s0)
    CHKW 0, s0                      // 0
    sw zero, 0(s0)
    li t3, 1
    sb t3, 3(s0)
    CHKW 0, s0                      // 0
    sw zero, 0(s0)
    li t3, 1
    sh t3, 2(s0)
    CHKW 0, s0                      // 0
    sw zero, 0(s0)
    li t3, 1
    sh t3, 0(s0)
    CHKW 0, s0                      // 1
// ... and leave it set
    sb zero, 1(s0)
    CHKW 0, s0                      // 1
    li t3, 1
    sw t3, 0(s0)
    sb zero, 2(s0)
    CHKW 0, s0                      // 1
    li t3, 1
    sw t3, 0(s0)
    sb zero, 3(s0)
    CHKW 0, s0                      // 1
    li t3, 1
    sw t3, 0(s0)
    sh zero, 2(s0)
    CHKW 0, s0                      // 1
    CHK_MSIP                        // 1
    sw zero, 0(s0)

// ---------------- MSIP slots of other harts (this system has hart 0 only) ----------------
    li t3, 1
    sw t3, 4(s0)                    // hart 1 msip
    CHKW 0, s0                      // 0: hart 0 unchanged
    CHK_MSIP                        // 0
    sw zero, 0(s0)
    li t3, 1
    sw t3, 8(s0)                    // hart 2 msip
    CHKW 0, s0                      // 0
    sw zero, 0(s0)
    li t3, 1
    sw t3, 0(s0)
    sw zero, 4(s0)                  // hart 1 msip
    CHKW 0, s0                      // 1: hart 0 unchanged
    sw zero, 0(s0)
    CHKW 4, s0                      // 0 (no hart 1: implementation defined, expected 0)
    li t4, CLINT + 0x3FFC
    CHKW 0, t4                      // 0 (reserved: implementation defined, expected 0)
#if __riscv_xlen == 64
    li t3, 1
    sd t3, 0(s0)                    // doubleword covering hart 0 and hart 1 msip
    CHKW 0, s0                      // 1
    slli t3, t3, 32
    sd t3, 0(s0)                    // writes 1 to hart 1, 0 to hart 0
    CHKW 0, s0                      // 0
#else
    li t3, 1
    sw t3, 0(s0)
    CHKW 0, s0                      // 1
    sw zero, 0(s0)
    CHKW 0, s0                      // 0
#endif
    sw zero, 0(s0)

// ---------------- MTIMECMP: 64-bit read-write [ACLINT 2.3]; every access size ----------------
    SETCMP 0x01234567, 0x89ABCDEF
    CHKW 0, s1
    CHKW 4, s1
    CHKB 0, s1
    CHKB 1, s1
    CHKB 2, s1
    CHKB 3, s1
    CHKB 4, s1
    CHKB 5, s1
    CHKB 6, s1
    CHKB 7, s1
    CHKH 0, s1
    CHKH 2, s1
    CHKH 4, s1
    CHKH 6, s1
#if __riscv_xlen == 64
    ld t2, 0(s1)
    SIGR t2                         // 0x0123456789ABCDEF
#else
    CHKW 4, s1                      // 0x01234567
#endif

// Byte stores: each changes only its byte
.irp k, 0, 1, 2, 3, 4, 5, 6, 7
    SETCMP 0x01234567, 0x89ABCDEF
    li t3, 0xA5
    sb t3, \k(s1)
    CHKW 0, s1
    CHKW 4, s1
.endr
// Halfword stores
.irp k, 0, 2, 4, 6
    SETCMP 0x01234567, 0x89ABCDEF
    li t3, 0x5AA5
    sh t3, \k(s1)
    CHKW 0, s1
    CHKW 4, s1
.endr
// Word stores (on RV64 too)
.irp k, 0, 4
    SETCMP 0x01234567, 0x89ABCDEF
    li t3, 0xDEADBEEF
    sw t3, \k(s1)
    CHKW 0, s1
    CHKW 4, s1
.endr
// Doubleword store (RV64); a pair of word stores on RV32
#if __riscv_xlen == 64
    li t3, 0xFEDCBA9876543210
    sd t3, 0(s1)
#else
    li t3, 0x76543210
    sw t3, 0(s1)
    li t3, 0xFEDCBA98
    sw t3, 4(s1)
#endif
    CHKW 0, s1
    CHKW 4, s1
// Hart 1 mtimecmp slot: does not change hart 0's
    SETCMP 0x01234567, 0x89ABCDEF
    li t3, 0x12345678
    sw t3, 8(s1)
    sw t3, 12(s1)
    CHKW 0, s1
    CHKW 4, s1
    CHKW 8, s1                      // 0 (no hart 1: implementation defined, expected 0)
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF

// ---------------- MTIME: 64-bit read-write counter [ACLINT 2.2]; partial writes ----------------
// The counter keeps running, so only bytes that cannot change in the few cycles between write and
// read are compared exactly.
    SETTIME 0x11223344, 0
    jal ra, clint_read_mtime
    SIG32 a1                        // 0x11223344
    li t3, 0x1000
    SIG_LTU a0, t3                  // 1: low word restarted from 0
    li t3, 0x55
    sb t3, 7(s2)
    CHKW 4, s2                      // 0x55223344
    li t3, 0x66
    sb t3, 4(s2)
    CHKW 4, s2                      // 0x55223366
    li t3, 0x7788
    sh t3, 4(s2)
    CHKW 4, s2                      // 0x55227788
    sw zero, 0(s2)
    li t3, 0x77
    sb t3, 2(s2)                    // mtime[23:16]
    sb zero, 0(s2)
    li t3, 0x99
    sb t3, 1(s2)                    // mtime[15:8]
    lw t4, 0(s2)
    ZEXT32 t4
    srli t2, t4, 16
    SIGR t2                         // 0x77
    srli t2, t4, 8
    andi t2, t2, 0xFF
    SIGR t2                         // 0x99
    CHKW 4, s2                      // 0x55227788: high word unchanged
    li t3, 0x1234
    sh t3, 2(s2)                    // mtime[31:16]
    lw t4, 0(s2)
    ZEXT32 t4
    srli t2, t4, 16
    SIGR t2                         // 0x1234
    li t3, 0xCAFEF00D
    sw t3, 4(s2)                    // mtime[63:32] (on RV64 too)
    CHKW 4, s2                      // 0xCAFEF00D
    lw t4, 0(s2)
    ZEXT32 t4
    srli t2, t4, 16
    SIGR t2                         // 0x1234: low word unchanged
#if __riscv_xlen == 64
    li t3, 0x0000ABCD00000000
    sd t3, 0(s2)
#else
    sw zero, 0(s2)
    li t3, 0xABCD
    sw t3, 4(s2)
#endif
    CHKW 4, s2                      // 0xABCD
    lw t4, 0(s2)
    ZEXT32 t4
    li t3, 0x1000
    SIG_LTU t4, t3                  // 1

// Counting: two reads in a row increase
    lw t4, 0(s2)
    lw t5, 0(s2)
    ZEXT32 t4
    ZEXT32 t5
    SIG_LTU t4, t5                  // 1
// Carry from the low word into the high word
    SETTIME 0x12345678, 0xFFFFFF00
    DELAY 0x400
    jal ra, clint_read_mtime
    SIG32 a1                        // 0x12345679
    li t3, 0x1000
    SIG_LTU a0, t3                  // 1
// 64-bit wrap
    SETTIME 0xFFFFFFFF, 0xFFFFFF00
    DELAY 0x400
    jal ra, clint_read_mtime
    SIG32 a1                        // 0
    li t3, 0x1000
    SIG_LTU a0, t3                  // 1

// ---------------- Unmapped offsets (implementation defined; expected to read 0 and ignore writes) ----------------
    SETTIME 0x00C0FFEE, 0
    li t4, CLINT + 0xBFF0
    CHKW 0, t4                      // 0
    CHKW 4, t4                      // 0
    li t3, -1
    sw t3, 0(t4)
    sw t3, 4(t4)
    li t4, CLINT + 0x7FF8           // where MTIME sits in a standalone ACLINT MTIMER
    CHKW 0, t4                      // 0
    CHKW 4, t4                      // 0
    sw t3, 0(t4)
    sw t3, 4(t4)
    li t4, CLINT + 0xC000
    CHKW 0, t4                      // 0
    sw t3, 0(t4)
    li t4, CLINT + 0xFFFC
    CHKW 0, t4                      // 0
    sw t3, 0(t4)
    li t4, CLINT + 0x0010
    sw t3, 0(t4)                    // hart 4 msip
    CHKW 4, s2                      // 0x00C0FFEE: mtime unchanged
    CHKW 0, s1                      // 0xFFFFFFFF: mtimecmp unchanged
    CHKW 4, s1                      // 0xFFFFFFFF
    CHKW 0, s0                      // 0: msip unchanged
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF

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
WORD 0, 0, 0, 1, 0                                      // 0: reset: msip, mip.MSIP, mtime hi, mtime lo small, mip.MTIP
WORD 1, 1, 1, 0, 0, 1, 0                                // 5: msip word writes
WORD 1, 0, 0, 0, 1, 0                                   // 12: msip byte/halfword reads
WORD 1, 0, 1, 0                                         // 18: sb to byte 0
WORD 0, 0, 0, 0, 1                                      // 22: sb/sh to bytes 1-3 leave msip clear; sh to 0 sets
WORD 1, 1, 1, 1, 1                                      // 27: sb/sh to bytes 1-3 leave msip set; mip.MSIP
WORD 0, 0, 0, 1, 0, 0                                   // 32: other harts' msip, reserved
WORD 1, 0                                               // 38: doubleword (RV64) / word (RV32) store
WORD 0x89ABCDEF, 0x01234567                             // 40: mtimecmp words
WORD 0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01     // 42: mtimecmp bytes
WORD 0xCDEF, 0x89AB, 0x4567, 0x0123                     // 50: mtimecmp halfwords
#if __riscv_xlen == 64
WORD 0x0123456789ABCDEF                                 // 54: mtimecmp doubleword
#else
WORD 0x01234567                                         // 54: mtimecmp high word
#endif
WORD 0x89ABCDA5, 0x01234567                             // 55: sb byte 0
WORD 0x89ABA5EF, 0x01234567                             // 57: sb byte 1
WORD 0x89A5CDEF, 0x01234567                             // 59: sb byte 2
WORD 0xA5ABCDEF, 0x01234567                             // 61: sb byte 3
WORD 0x89ABCDEF, 0x012345A5                             // 63: sb byte 4
WORD 0x89ABCDEF, 0x0123A567                             // 65: sb byte 5
WORD 0x89ABCDEF, 0x01A54567                             // 67: sb byte 6
WORD 0x89ABCDEF, 0xA5234567                             // 69: sb byte 7
WORD 0x89AB5AA5, 0x01234567                             // 71: sh half 0
WORD 0x5AA5CDEF, 0x01234567                             // 73: sh half 1
WORD 0x89ABCDEF, 0x01235AA5                             // 75: sh half 2
WORD 0x89ABCDEF, 0x5AA54567                             // 77: sh half 3
WORD 0xDEADBEEF, 0x01234567                             // 79: sw word 0
WORD 0x89ABCDEF, 0xDEADBEEF                             // 81: sw word 1
WORD 0x76543210, 0xFEDCBA98                             // 83: sd
WORD 0x89ABCDEF, 0x01234567, 0                          // 85: hart 1 mtimecmp slot
WORD 0x11223344, 1                                      // 88: mtime write
WORD 0x55223344, 0x55223366, 0x55227788                 // 90: mtime sb/sh to the high word
WORD 0x77, 0x99, 0x55227788                             // 93: mtime sb to the low word
WORD 0x1234                                             // 96: mtime sh to the low word
WORD 0xCAFEF00D, 0x1234                                 // 97: mtime sw to the high word
WORD 0xABCD, 1                                          // 99: mtime doubleword
WORD 1                                                  // 101: mtime counts
WORD 0x12345679, 1                                      // 102: carry into the high word
WORD 0, 1                                               // 104: 64-bit wrap
WORD 0, 0, 0, 0, 0, 0                                   // 106: unmapped reads
WORD 0x00C0FFEE, 0xFFFFFFFF, 0xFFFFFFFF, 0              // 112: unmapped writes change nothing
WORD 0x0B                                               // 116: ecall from test termination
expected_signature_end:
