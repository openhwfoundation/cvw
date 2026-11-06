///////////////////////////////////////////
// WALLY-clint.h
//
// Purpose: CLINT register map, signature macros, and helper routines shared by the WALLY-clint-*
//          peripheral tests.  The expected values in those tests follow the specifications, not the
//          current RTL:
//            [ACLINT] RISC-V Advanced Core Local Interruptor Specification v1.0-rc4
//                     (github.com/riscvarchive/riscv-aclint): MTIMER (sec. 2) and MSWI (sec. 3)
//                     devices; the SiFive CLINT layout puts MSWI at +0x0000, the MTIMECMP array at
//                     +0x4000 (8 bytes per hart), and MTIME at +0xBFF8.
//            [PRIV]   RISC-V Privileged Architecture, "Machine Timer (mtime and mtimecmp)
//                     Registers" and "Machine Interrupt (mip and mie) Registers"; Sstc for stimecmp.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// Specification points the tests rely on:
//   - MSIP (hart 0 at +0x0) is a 32-bit WARL register: bits 31:1 are wired to zero and bit 0 is
//     reflected in mip.MSIP.  Reset value 0.  [ACLINT 3.2]
//   - MTIME is a 64-bit read-write counter, cleared to zero on reset.  MTIMECMP is a 64-bit
//     read-write register whose reset value is unknown.  [ACLINT 2.2, 2.3]
//   - A machine timer interrupt is pending whenever mtime >= mtimecmp, treating the values as
//     unsigned integers, and stays pending until mtimecmp becomes greater than mtime.  [PRIV]
//   - On RV32, memory-mapped writes to mtimecmp modify only one 32-bit part of the register.  [PRIV]
//   - mip.MTIP and mip.MSIP are read-only in mip.  [PRIV]
//   - time/timeh are read-only shadows of mtime.  [PRIV, Zicntr]
//   - A store writes only the bytes it addresses: the PMA of this platform accepts byte, halfword,
//     word (and on RV64 doubleword) accesses to the CLINT region (adrdecs.sv), so a narrow store
//     must not change bytes it does not cover, and a store to another hart's slot must not change
//     hart 0's registers.
//
// Register use (besides those the test library reserves: t1, a6, s9-s11, sp, tp):
//   s0     CLINT base (MSIP of hart 0)
//   s1     MTIMECMP of hart 0
//   s2     MTIME
//   s3-s8  free for the tests; preserved by the helpers
//   a0-a5, t0, t2-t6, ra: arguments and scratch, clobbered by the helpers

.equ CLINT,          0x02000000
.equ CLINT_MSIP,     0x02000000   // hart 0 msip; hart h at +4*h
.equ CLINT_MTIMECMP, 0x02004000   // hart 0 mtimecmp; hart h at +8*h
.equ CLINT_MTIME,    0x0200BFF8

.equ MIP_MSIP, 0x008
.equ MIP_MTIP, 0x080
.equ MIP_STIP, 0x020

// CSR numbers (numeric so the tests do not depend on the assembler knowing the names)
.equ CSR_MCYCLE,    0xB00
.equ CSR_TIME,      0xC01
.equ CSR_TIMEH,     0xC81
.equ CSR_MENVCFG,   0x30A
.equ CSR_MENVCFGH,  0x31A
.equ CSR_STIMECMP,  0x14D
.equ CSR_STIMECMPH, 0x15D

// Interrupt mcause values
#if __riscv_xlen == 64
#define MCAUSE_INT(n) (0x8000000000000000 | (n))
#else
#define MCAUSE_INT(n) (0x80000000 | (n))
#endif

// Zero-extend the low 32 bits of \reg (no-op on RV32).
.macro ZEXT32 reg
#if __riscv_xlen == 64
    slli \reg, \reg, 32
    srli \reg, \reg, 32
#endif
.endm

// Append register \reg to the signature and check it.
.macro SIGR reg
    SREG \reg, 0(t1)
    SIG_NEXT
.endm

// Append the low 32 bits of \reg, zero extended, so the entry is the same on RV32 and RV64.
.macro SIG32 reg
    ZEXT32 \reg
    SIGR \reg
.endm

// Append a constant.
.macro SIGI val
    li t2, \val
    SIGR t2
.endm

// Read a 32-bit word / halfword / byte at \off(\base) into the signature (zero extended).
.macro CHKW off, base
    lw t2, \off(\base)
    SIG32 t2
.endm
.macro CHKH off, base
    lhu t2, \off(\base)
    SIGR t2
.endm
.macro CHKB off, base
    lbu t2, \off(\base)
    SIGR t2
.endm

// Append mip.MTIP / mip.MSIP / mip.STIP (0 or 1).
.macro CHK_MTIP
    csrr t2, mip
    srli t2, t2, 7
    andi t2, t2, 1
    SIGR t2
.endm
.macro CHK_MSIP
    csrr t2, mip
    srli t2, t2, 3
    andi t2, t2, 1
    SIGR t2
.endm
.macro CHK_STIP
    csrr t2, mip
    srli t2, t2, 5
    andi t2, t2, 1
    SIGR t2
.endm

// Poll until mip.MTIP == \val (at most about 200000 polls), then append mip.MTIP.
.macro POLL_MTIP val
    li a0, \val
    jal ra, clint_poll_mtip
    CHK_MTIP
.endm

// mtimecmp = {\hi, \lo} with the RV32 sequence of [PRIV] (lo = -1, hi, lo) or one sd on RV64.
.macro SETCMP hi, lo
    li a1, \hi
    li a0, \lo
    jal ra, clint_set_mtimecmp
.endm

// mtime = {\hi, \lo} (RV32: lo = 0, hi, lo so the low word cannot carry into the new high word).
.macro SETTIME hi, lo
    li a1, \hi
    li a0, \lo
    jal ra, clint_set_mtime
.endm

// Wait at least \n cycles (mcycle).
.macro DELAY n
    li a0, \n
    jal ra, clint_delay
.endm

// Append 1 if the unsigned register comparison \a < \b holds, else 0 (uses t2).
.macro SIG_LTU a, b
    sltu t2, \a, \b
    SIGR t2
.endm

// Helper routines.  Place CLINT_HELPERS once in each test, after END_TESTS.
.macro CLINT_HELPERS

// clint_set_mtimecmp: mtimecmp = {a1, a0}.  Uses t2, t3.
clint_set_mtimecmp:
#if __riscv_xlen == 64
    slli t2, a1, 32
    slli t3, a0, 32
    srli t3, t3, 32
    or   t2, t2, t3
    sd   t2, 0(s1)
#else
    li   t2, -1
    sw   t2, 0(s1)     // no smaller than the old value: no spurious interrupt
    sw   a1, 4(s1)
    sw   a0, 0(s1)
#endif
    ret

// clint_set_mtime: mtime = {a1, a0}.  Uses t2, t3.
clint_set_mtime:
#if __riscv_xlen == 64
    slli t2, a1, 32
    slli t3, a0, 32
    srli t3, t3, 32
    or   t2, t2, t3
    sd   t2, 0(s2)
#else
    sw   zero, 0(s2)
    sw   a1, 4(s2)
    sw   a0, 0(s2)
#endif
    ret

// clint_read_mtime: {a1, a0} = mtime (both zero extended; consistent hi/lo pair on RV32).  Uses t2.
clint_read_mtime:
#if __riscv_xlen == 64
    ld   t2, 0(s2)
    slli a0, t2, 32
    srli a0, a0, 32
    srli a1, t2, 32
#else
1:
    lw   a1, 4(s2)
    lw   a0, 0(s2)
    lw   t2, 4(s2)
    bne  a1, t2, 1b
#endif
    ret

// clint_read_mtimecmp: {a1, a0} = mtimecmp (32-bit loads, zero extended).
clint_read_mtimecmp:
    lw   a0, 0(s1)
    ZEXT32 a0
    lw   a1, 4(s1)
    ZEXT32 a1
    ret

// clint_delay: wait at least a0 cycles.  Uses t2, t3.
clint_delay:
    csrr t2, CSR_MCYCLE
1:
    csrr t3, CSR_MCYCLE
    sub  t3, t3, t2
    bltu t3, a0, 1b
    ret

// clint_poll_mtip: poll until mip.MTIP == a0, at most about 200000 times.  Uses t2, t3.
clint_poll_mtip:
    li   t3, 200000
1:
    csrr t2, mip
    srli t2, t2, 7
    andi t2, t2, 1
    beq  t2, a0, 2f
    addi t3, t3, -1
    bnez t3, 1b
2:
    ret
.endm
