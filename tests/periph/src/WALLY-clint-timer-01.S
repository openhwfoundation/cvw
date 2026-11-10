///////////////////////////////////////////
// WALLY-clint-timer-01.S
//
// Purpose: CLINT timer and software interrupts: mip.MTIP = (mtime >= mtimecmp) as an unsigned 64-bit
//          compare, including the boundaries, bit 63, carries between the 32-bit halves, and the RV32
//          mtimecmp update sequence; read-only mip.MTIP/MSIP; time/timeh as a shadow of mtime; and
//          taking, masking, prioritizing, and clearing the machine timer and software interrupts.
//          Expected values follow the ACLINT and privileged specifications (see WALLY-clint.h).
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
    li s3, 0                        // number of interrupts taken by clint_trap
    sw zero, 0(s0)
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF

// ---------------- mip.MTIP and mip.MSIP are read-only in mip [PRIV] ----------------
    li t3, MIP_MTIP | MIP_MSIP
    csrs mip, t3
    CHK_MTIP                        // 0
    CHK_MSIP                        // 0
    li t3, 1
    sw t3, 0(s0)
    SETCMP 0, 0
    CHK_MTIP                        // 1
    CHK_MSIP                        // 1
    li t3, MIP_MTIP | MIP_MSIP
    csrc mip, t3
    CHK_MTIP                        // 1
    CHK_MSIP                        // 1
    sw zero, 0(s0)
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF
    CHK_MTIP                        // 0
    CHK_MSIP                        // 0

// ---------------- MTIP = mtime >= mtimecmp, unsigned [PRIV; ACLINT 2.3] ----------------
    SETCMP 0, 0
    SETTIME 0, 0
    CHK_MTIP                        // 1: mtimecmp = 0
    SETTIME 0xFFFFFFFF, 0
    CHK_MTIP                        // 1
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF
    CHK_MTIP                        // 0: mtimecmp = all ones
    SETCMP 0x80000000, 0
    SETTIME 0x7FFFFFFF, 0
    CHK_MTIP                        // 0: a signed compare would say 1
    SETTIME 0x80000000, 0
    CHK_MTIP                        // 1
    SETCMP 0, 0x10000
    SETTIME 0xFFFFFFFF, 0
    CHK_MTIP                        // 1: a signed compare would say 0
    SETCMP 0x7FFFFFFF, 0xFFFFFFFF
    SETTIME 0x80000000, 0
    CHK_MTIP                        // 1
// mtime == mtimecmp
    SETCMP 5, 0x1000
    SETTIME 5, 0x1000
    CHK_MTIP                        // 1
    DELAY 0x100
    CHK_MTIP                        // 1: level, stays pending
// The high word of mtimecmp alone decides
    SETCMP 5, 0x80000000
    SETTIME 5, 0
    CHK_MTIP                        // 0
    li t3, 4
    sw t3, 4(s1)                    // mtimecmp = {4, 0x80000000}
    CHK_MTIP                        // 1
    li t3, 6
    sw t3, 4(s1)                    // {6, 0x80000000}
    CHK_MTIP                        // 0
    li t3, 5
    sw t3, 4(s1)                    // {5, 0x80000000}
    CHK_MTIP                        // 0
    sw zero, 0(s1)                  // {5, 0}
    CHK_MTIP                        // 1
// The low word of mtime carries into the high word: mtimecmp = {1, 0}
    SETCMP 1, 0
    SETTIME 0, 0xFFFFFF00
    CHK_MTIP                        // 0
    POLL_MTIP 1                     // 1
    jal ra, clint_read_mtime
    SIG32 a1                        // 1
// mtime wraps from all ones to 0 with mtimecmp = all ones
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF
    SETTIME 0xFFFFFFFF, 0xFFFFFE00
    CHK_MTIP                        // 0
    DELAY 0x400
    CHK_MTIP                        // 0
    jal ra, clint_read_mtime
    SIG32 a1                        // 0: wrapped
// MTIP rises when the counting mtime reaches mtimecmp, and not before
    SETCMP 9, 0x2000
    SETTIME 9, 0
    CHK_MTIP                        // 0
    li a0, 0x2000
    jal ra, clint_mtip_edge
    SIGR a0                         // 0 violations
    lw t4, 0(s2)
    ZEXT32 t4
    li t3, 0x2000
    sltu t2, t4, t3
    SIGR t2                         // 0: mtime >= mtimecmp
// Clearing: raising mtimecmp above mtime clears MTIP; lowering it sets it again
    SETCMP 9, 0xFFFFFFFF
    CHK_MTIP                        // 0
    SETCMP 9, 0
    CHK_MTIP                        // 1
    li t3, 10
    sw t3, 4(s1)                    // high word only
    CHK_MTIP                        // 0
// Writing mtime below mtimecmp also clears MTIP
    SETCMP 0x30, 0
    SETTIME 0x30, 0x10
    CHK_MTIP                        // 1
    SETTIME 0x2F, 0
    CHK_MTIP                        // 0

// ---------------- 32-bit writes to mtimecmp change one half [PRIV, "On RV32, memory-mapped writes to
// mtimecmp modify only one 32-bit part of the register"]; the spec's update sequence never makes
// mtimecmp smaller than both its old and new values ----------------
// mtime = {2, 0x100}; old mtimecmp = {3, 0}; new mtimecmp = {2, 0x80000000}
    SETCMP 3, 0
    SETTIME 2, 0x100
    CHK_MTIP                        // 0
    li t3, -1
    sw t3, 0(s1)                    // {3, 0xFFFFFFFF}
    CHK_MTIP                        // 0
    li t3, 2
    sw t3, 4(s1)                    // {2, 0xFFFFFFFF}
    CHK_MTIP                        // 0
    li t3, 0x80000000
    sw t3, 0(s1)                    // {2, 0x80000000}
    CHK_MTIP                        // 0
    CHKW 0, s1                      // 0x80000000
    CHKW 4, s1                      // 2
// Writing the high word first passes through {2, 0}, which is pending
    SETCMP 3, 0
    li t3, 2
    sw t3, 4(s1)                    // {2, 0}
    CHK_MTIP                        // 1
    li t3, 0x80000000
    sw t3, 0(s1)                    // {2, 0x80000000}
    CHK_MTIP                        // 0

// ---------------- time (and timeh on RV32) is a read-only shadow of mtime [PRIV, Zicntr] ----------------
// In S and U mode, time reads mtime when mcounteren.TM (and for U, scounteren.TM) is set, and is an
// illegal instruction otherwise [PRIV, "Machine Counter-Enable Register"].  The library trap handler
// records the mcause of each ecall and illegal instruction.
.macro RD_TIME_HI
#if __riscv_xlen == 32
    csrr t4, CSR_TIMEH
#else
    csrr t4, CSR_TIME
    srli t4, t4, 32
#endif
.endm
    SETTIME 0x5555, 0
    csrsi mcounteren, 2
    csrsi scounteren, 2
    li a0, 3
    ecall                           // to S mode
    RD_TIME_HI
    SIG32 t4                        // 0x5555
    li a0, 4
    ecall                           // to U mode
    RD_TIME_HI
    SIG32 t4                        // 0x5555
    li a0, 2
    ecall                           // to M mode
    csrci mcounteren, 2
    li a0, 3
    ecall                           // to S mode
    RD_TIME_HI                      // illegal instruction: mcounteren.TM = 0
    li a0, 2
    ecall
    csrsi mcounteren, 2
    csrci scounteren, 2
    li a0, 4
    ecall                           // to U mode
    RD_TIME_HI                      // illegal instruction: scounteren.TM = 0
    li a0, 2
    ecall
    csrci mcounteren, 2
// In M mode
    la t3, clint_trap
    csrrw s8, mtvec, t3             // s8 = library trap handler (restored at the end)
    SETTIME 0xABCD, 0
    lw s4, 0(s2)                    // mtime[31:0] before
    csrr s5, CSR_TIME
#if __riscv_xlen == 32
    csrr s6, CSR_TIMEH
#else
    srli s6, s5, 32
#endif
    lw s7, 0(s2)                    // mtime[31:0] after
    ZEXT32 s4
    ZEXT32 s5
    ZEXT32 s7
    SIG32 s6                        // 0xABCD
    sltu t2, s5, s4
    SIGR t2                         // 0: time >= earlier mtime
    sltu t2, s7, s5
    SIGR t2                         // 0: time <= later mtime
    SETTIME 0x1234, 0
#if __riscv_xlen == 32
    csrr s6, CSR_TIMEH
#else
    csrr s6, CSR_TIME
    srli s6, s6, 32
#endif
    SIG32 s6                        // 0x1234
    csrrw x0, CSR_TIME, x0          // illegal instruction: time is read-only
    li t3, 1
    csrrs x0, CSR_TIME, t3          // illegal instruction

// ---------------- Taking the interrupts [PRIV] ----------------
// Machine-mode interrupts are taken when mstatus.MIE = 1 and the mie bit is set.
    SETCMP 0, 0                     // MTIP pending
    csrw mie, zero
    csrsi mstatus, 8
    nop
    nop
    nop
    nop
    nop
    SIGR s3                         // 0: mie.MTIE = 0
    csrci mstatus, 8
    li t3, MIP_MTIP
    csrs mie, t3
    nop
    nop
    nop
    nop
    nop
    SIGR s3                         // 0: mstatus.MIE = 0
    csrsi mstatus, 8                // taken: clint_trap records the cause and raises mtimecmp
    nop
    nop
    nop
    nop
    SIGR s3                         // 1
    CHK_MTIP                        // 0
    li t3, MIP_MSIP
    csrs mie, t3
    li t3, 1
    sw t3, 0(s0)                    // taken: clint_trap records the cause and clears msip
    nop
    nop
    nop
    nop
    SIGR s3                         // 2
    CHK_MSIP                        // 0
// Both pending: MSI is taken before MTI
    csrci mstatus, 8
    li t3, 1
    sw t3, 0(s0)
    SETCMP 0, 0
    csrsi mstatus, 8
    nop
    nop
    nop
    nop
    SIGR s3                         // 4
// Timer interrupt when the counting mtime reaches mtimecmp
    SETTIME 0x20, 0
    SETCMP 0x20, 0x800
    li t4, 100000
1:
    li t3, 5
    beq s3, t3, 2f
    addi t4, t4, -1
    bnez t4, 1b
2:
    SIGR s3                         // 5
    lw t4, 0(s2)
    ZEXT32 t4
    li t3, 0x800
    sltu t2, t4, t3
    SIGR t2                         // 0: mtime >= 0x800 by then
// WFI with mstatus.MIE = 0 resumes when the enabled MTIP becomes pending, without a trap
    csrci mstatus, 8
    li t3, MIP_MTIP
    csrw mie, t3
    SETTIME 0x40, 0
    SETCMP 0x40, 0x400
    wfi
    POLL_MTIP 1                     // 1
    SIGR s3                         // 5: no trap
    csrsi mstatus, 8                // now taken
    nop
    nop
    nop
    nop
    SIGR s3                         // 6
    csrci mstatus, 8
    csrw mie, zero
    sw zero, 0(s0)
    SETCMP 0xFFFFFFFF, 0xFFFFFFFF
    csrw mtvec, s8

END_TESTS

CLINT_HELPERS

// clint_trap: direct-mode trap handler for this test.  Records mcause.  On an interrupt, counts it in
// s3 and clears its source (mtimecmp = all ones for MTI, msip = 0 for MSI); on an exception, skips
// the instruction.  Uses t2 and t3, so the test holds nothing in them where a trap can occur.
.align 6
clint_trap:
    csrr t2, mcause
    SIGR t2
    csrr t2, mcause
    bltz t2, 7f
    csrr t2, mepc
    addi t2, t2, 4
    csrw mepc, t2
    mret
7:
    addi s3, s3, 1
    slli t2, t2, 1
    srli t2, t2, 1
    li t3, 7
    bne t2, t3, 8f
    li t3, -1
    sw t3, 0(s1)
    sw t3, 4(s1)
    mret
8:
    sw zero, 0(s0)
    mret

// clint_mtip_edge: with the high words of mtime and mtimecmp equal and a0 = mtimecmp[31:0], poll
// until MTIP is set, checking on every poll that MTIP agrees with the mtime values read just before
// and just after mip.  Returns a0 = number of disagreements (+0x100 if MTIP never rose).
clint_mtip_edge:
    li a1, 0
    li a2, 1000000
1:
    lw t3, 0(s2)
    csrr t4, mip
    lw t5, 0(s2)
    ZEXT32 t3
    ZEXT32 t5
    andi t4, t4, MIP_MTIP
    bnez t4, 3f
    bltu t3, a0, 2f
    addi a1, a1, 1                  // MTIP clear although mtime had reached mtimecmp
2:
    addi a2, a2, -1
    bnez a2, 1b
    addi a1, a1, 0x100
    j 4f
3:
    bgeu t5, a0, 4f
    addi a1, a1, 1                  // MTIP set although mtime < mtimecmp
4:
    mv a0, a1
    ret

TEST_STACK_AND_DATA

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each; 32-bit values are zero extended on RV64).
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0, 0, 1, 1, 1, 1, 0, 0                             // 0: mip.MTIP/MSIP read-only
WORD 1, 1, 0, 0, 1, 1, 1                                // 8: compare: 0, all ones, bit 63 unsigned
WORD 1, 1                                               // 15: mtime == mtimecmp, level
WORD 0, 1, 0, 0, 1                                      // 17: high word of mtimecmp
WORD 0, 1, 1                                            // 22: carry into the high word
WORD 0, 0, 0                                            // 25: wrap
WORD 0, 0, 0                                            // 28: rising edge
WORD 0, 1, 0                                            // 31: clearing by mtimecmp
WORD 1, 0                                               // 34: clearing by mtime
WORD 0, 0, 0, 0, 0x80000000, 2                          // 36: RV32 update sequence
WORD 1, 0                                               // 42: high word first
WORD 0x0B, 0x5555, 0x09, 0x5555, 0x08                  // 44: time in S and U mode
WORD 0x0B, 2, 0x09, 0x0B, 2, 0x08                       // 49: time with mcounteren.TM / scounteren.TM = 0
WORD 0xABCD, 0, 0, 0x1234                               // 55: time CSR in M mode
WORD 2, 2                                               // 59: writes to time are illegal
WORD 0, 0                                               // 61: masked by mie, mstatus.MIE
WORD MCAUSE_INT(7), 1, 0                                // 63: MTI taken and cleared
WORD MCAUSE_INT(3), 2, 0                                // 66: MSI taken and cleared
WORD MCAUSE_INT(3), MCAUSE_INT(7), 4                    // 69: MSI before MTI
WORD MCAUSE_INT(7), 5, 0                                // 72: MTI from counting
WORD 1, 5, MCAUSE_INT(7), 6                             // 75: WFI wake, then taken
WORD 0x0B                                               // 79: ecall from test termination
expected_signature_end:
