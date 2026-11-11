///////////////////////////////////////////
// WALLY-plic.h
//
// Purpose: PLIC register map, check macros, interrupt-source controls, and helper routines shared
//          by the WALLY-plic-stress-* peripheral tests.  The expected values in those tests follow
//          the RISC-V Platform-Level Interrupt Controller Specification v1.0.0 (riscv-plic-spec,
//          riscv-plic.adoc), cited by section, rather than the current RTL.  Values the spec leaves
//          to the implementation (priority and threshold widths, reset values, the value read from a
//          reserved address) are marked "impl" and use what the Wally configuration documents:
//          3-bit priorities and thresholds, PLIC_NUM_SRC = 14, contexts 0 (M) and 1 (S) of hart 0.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// The tests run in machine mode with mstatus.MIE = 0, so the PLIC is observed by polling mip.MEIP
// (bit 11, context 0) and mip.SEIP (bit 9, context 1) and the claim registers; no interrupt trap is
// taken.  Each check writes one signature entry and records its expected value in place, next to
// the code that produces it: EXPECT appends the value to the expected_signature table (.data
// subsection 1) and the source line to the non-allocated .plic_lines section, so a SELFCHECK_ALL
// mismatch at entry N maps to the Nth word of .plic_lines (objdump -s -j .plic_lines).
//
// Interrupt sources (all level-sensitive, driven from software through their devices):
//   3  GPIO   pin 0 looped back (GPIO_LOOPBACK_TEST), high_ie[0]: line = pin 0 high
//   6  SPI    txmark = 1 with an empty transmit FIFO sets ip.txwm; line = ie.txwm
//   10 UART   THR empty; line = IER.ETBEI (IIR is never read, so THRE is never squashed)
//   11-14 PWM pwmcmpN = 0 makes comparator N match continuously; line = (pwmcmpN == 0)
//
// Register use (besides those the test library reserves: t1, a6, s9-s11, sp, tp):
//   t0, t2-t6, a0-a5, ra: scratch, clobbered by the macros and helpers.  s0-s8 are free.

.equ PLIC,           0x0C000000
.equ PLIC_PRIO,      0x000000   // + 4*source
.equ PLIC_PEND0,     0x001000
.equ PLIC_PEND1,     0x001004
.equ PLIC_EN0,       0x002000   // context 0 sources 0-31; context n at + 0x80*n
.equ PLIC_EN1,       0x002080
.equ PLIC_THRESH0,   0x200000   // context n at + 0x1000*n
.equ PLIC_CLAIM0,    0x200004
.equ PLIC_THRESH1,   0x201000
.equ PLIC_CLAIM1,    0x201004

.equ GPIO,           0x10060000
.equ GPIO_INPUT_EN,  0x04
.equ GPIO_OUTPUT_EN, 0x08
.equ GPIO_OUTPUT_VAL,0x0C
.equ GPIO_HIGH_IE,   0x28
.equ GPIO_HIGH_IP,   0x2C
.equ SPI,            0x10040000
.equ SPI_TXMARK,     0x50
.equ SPI_IE,         0x70
.equ UART,           0x10000000
.equ UART_IER,       1
.equ PWM,            0x10020000
.equ PWM_CFG,        0x00
.equ PWM_CMP0,       0x20

.equ MIP_SEIP,       0x200
.equ MIP_MEIP,       0x800
// Number of sources.  The test ELFs are built for the standard configurations (PLIC_NUM_SRC = 14);
// build with -DPLIC_NSRC=53 for the 53-source derivatives (buildroot, spitest).  The sources the
// tests drive are all below 15, so only the register-map checks depend on PLIC_NSRC.
#ifndef PLIC_NSRC
#define PLIC_NSRC 14
#endif
.equ NSRC,           PLIC_NSRC
.if NSRC >= 31
.equ ALLSRC,         0xFFFFFFFE                  // enable/pending word 0: sources 1..31
.else
.equ ALLSRC,         (1 << (NSRC+1)) - 2         // enable/pending word 0: sources 1..NSRC
.endif
.if NSRC >= 32
.equ ALLSRC1,        (1 << (NSRC-31)) - 1        // enable/pending word 1: sources 32..NSRC
.else
.equ ALLSRC1,        0
.endif

// ---------------------------------------------------------------------------------------------
// Expected-value bookkeeping
// ---------------------------------------------------------------------------------------------

// Append \val to the expected signature and \line to .plic_lines.
.macro EXPECT val, line
    .pushsection .data, 1
    WORD \val
    .popsection
    .pushsection .plic_lines, "", @progbits
    .4byte \line
    .popsection
.endm

// Place once, before any check: opens the expected_signature table.
.macro PLIC_EXPECTED_BEGIN
    .pushsection .data, 1
    .align 3
    .globl expected_signature
expected_signature:
    .popsection
.endm

// Place once, after the last check: the final entry is the mcause (0xB, ecall from M) that
// terminate_test records, then the end of the table.
.macro PLIC_EXPECTED_END
    EXPECT 0xB, 0
    .pushsection .data, 1
expected_signature_end:
    .popsection
.endm

// Append t2 to the signature and check it.
.macro SIGT2
    SREG t2, 0(t1)
    SIG_NEXT
.endm

// ---------------------------------------------------------------------------------------------
// Checks.  Each writes one signature entry.  These are cpp wrappers so that __LINE__ is the line
// of the check in the test source.
// ---------------------------------------------------------------------------------------------

// Read the 32-bit register at PLIC offset off (lw, so sign extended on RV64) and expect exp.
#define CHKR(off, exp)     CHKR_ (off), (exp), __LINE__
// Read the absolute address addr with lw and expect exp.
#define CHKA(addr, exp)    CHKA_ (addr), (exp), __LINE__
// Read mip & (MEIP | SEIP) and expect exp.
#define CHKMIP(exp)        CHKMIP_ (exp), __LINE__
// Claim for context ctx (0 = M, 1 = S) and expect source exp.
#define CLAIM(ctx, exp)    CHKR_ (PLIC_CLAIM0 + 0x1000*(ctx)), (exp), __LINE__
// Append a constant (for example a summary computed in the test) held in t2.
#define CHKT2(exp)         EXPECT (exp), __LINE__ ; SIGT2

.macro CHKR_ off, exp, line
    li t3, PLIC + \off
    li t2, 0xBAD
    lw t2, 0(t3)
    SIGT2
    EXPECT SEXT32(\exp), \line
.endm

.macro CHKA_ addr, exp, line
    li t3, \addr
    li t2, 0xBAD
    lw t2, 0(t3)
    SIGT2
    EXPECT SEXT32(\exp), \line
.endm

.macro CHKMIP_ exp, line
    csrr t2, mip
    li t3, MIP_MEIP | MIP_SEIP
    and t2, t2, t3
    SIGT2
    EXPECT \exp, \line
.endm

// ---------------------------------------------------------------------------------------------
// Register writes (no signature output)
// ---------------------------------------------------------------------------------------------

// Write 32-bit val to PLIC offset off.
.macro PW off, val
    li t3, PLIC + \off
    li t2, \val
    sw t2, 0(t3)
.endm

// Write 32-bit val to absolute address addr.
.macro AW addr, val
    li t3, \addr
    li t2, \val
    sw t2, 0(t3)
.endm

.macro PRIO src, val
    PW (PLIC_PRIO + 4*(\src)), \val
.endm

.macro COMPLETE ctx, id
    PW (PLIC_CLAIM0 + 0x1000*(\ctx)), \id
.endm

.macro THRESH ctx, val
    PW (PLIC_THRESH0 + 0x1000*(\ctx)), \val
.endm

.macro ENABLE ctx, mask
    PW (PLIC_EN0 + 0x80*(\ctx)), \mask
.endm

// Wait about 3*n cycles; long enough (n = 40) for a device line change to reach the PLIC pending
// bit and mip (GPIO input synchronizer, UART INTR flop, PLIC pending flop).
.macro SETTLE n=40
    li t2, \n
.Lsettle\@:
    addi t2, t2, -1
    bnez t2, .Lsettle\@
.endm

// ---------------------------------------------------------------------------------------------
// Interrupt-source lines.  SRC_HIGH / SRC_LOW drive the interrupt line of source id high / low
// through its device and wait for the change to reach the PLIC.  SRC_LOW does not touch the PLIC.
// ---------------------------------------------------------------------------------------------

.macro SRC_HIGH id
.if (\id) == 3
    AW GPIO + GPIO_OUTPUT_VAL, 1
.elseif (\id) == 6
    AW SPI + SPI_IE, 1
.elseif (\id) == 10
    li t3, UART
    li t2, 0x02
    sb t2, UART_IER(t3)
.elseif ((\id) >= 11) && ((\id) <= 14)
    AW PWM + PWM_CMP0 + 4*((\id) - 11), 0
.else
    .error "SRC_HIGH: not a controllable source"
.endif
    SETTLE
.endm

.macro SRC_LOW id
.if (\id) == 3
    AW GPIO + GPIO_OUTPUT_VAL, 0
    SETTLE
    AW GPIO + GPIO_HIGH_IP, 1          // high_ip is sticky: clear it once the pin is low
.elseif (\id) == 6
    AW SPI + SPI_IE, 0
.elseif (\id) == 10
    li t3, UART
    sb zero, UART_IER(t3)
.elseif ((\id) >= 11) && ((\id) <= 14)
    AW PWM + PWM_CMP0 + 4*((\id) - 11), 0xFFFF
    AW PWM + PWM_CFG, 0                // clear the sticky pwmcmpXip bits
.else
    .error "SRC_LOW: not a controllable source"
.endif
    SETTLE
.endm

// Drive every controllable source line low.
.macro SRC_ALL_LOW
    SRC_LOW 3
    SRC_LOW 6
    SRC_LOW 10
    SRC_LOW 11
    SRC_LOW 12
    SRC_LOW 13
    SRC_LOW 14
.endm

// Drive every controllable source line high.
.macro SRC_ALL_HIGH
    SRC_HIGH 3
    SRC_HIGH 6
    SRC_HIGH 10
    SRC_HIGH 11
    SRC_HIGH 12
    SRC_HIGH 13
    SRC_HIGH 14
.endm

// Set up the devices so that SRC_HIGH / SRC_LOW control their lines.  Leaves every line low.
.macro PLIC_SRC_INIT
    AW GPIO + GPIO_OUTPUT_VAL, 0
    AW GPIO + GPIO_INPUT_EN, 1
    AW GPIO + GPIO_OUTPUT_EN, 1
    AW GPIO + GPIO_HIGH_IE, 1
    AW SPI + SPI_IE, 0
    AW SPI + SPI_TXMARK, 1
    li t3, UART
    sb zero, UART_IER(t3)
    AW PWM + PWM_CFG, 0
    SRC_ALL_LOW
.endm

// Return the PLIC to a quiet state: every line low, nothing pending or in progress, all
// priorities, enables and thresholds 0.  No signature output.
.macro QUIESCE
    jal ra, plic_quiesce
.endm

// Helper routines.  Place PLIC_HELPERS once in each test, after END_TESTS.
.macro PLIC_HELPERS
plic_quiesce:
    mv a5, ra
    SRC_ALL_LOW
    li a0, PLIC
    li t2, 1
    li a1, 1
1:  slli t3, a1, 2                     // every source priority 1 so that every pending source is claimable
    add t3, t3, a0
    sw t2, 0(t3)
    addi a1, a1, 1
    li t3, 15
    blt a1, t3, 1b
    li t3, PLIC + PLIC_EN0
    li t2, ALLSRC
    sw t2, 0(t3)                       // enable every source in context 0
    li t3, PLIC + PLIC_EN1
    sw zero, 0(t3)
    li t4, PLIC + PLIC_CLAIM0
    li a2, 32
2:  lw t2, 0(t4)                       // claim until nothing is left pending
    addi a2, a2, -1
    beqz a2, 3f
    bnez t2, 2b
3:  li a1, 1
4:  sw a1, 0(t4)                       // complete every source (enabled in context 0)
    addi a1, a1, 1
    li t3, 15
    blt a1, t3, 4b
    li t3, PLIC + PLIC_EN0
    sw zero, 0(t3)
    li a1, 1
5:  slli t3, a1, 2
    add t3, t3, a0
    sw zero, 0(t3)
    addi a1, a1, 1
    li t3, 15
    blt a1, t3, 5b
    li t3, PLIC + PLIC_THRESH0
    sw zero, 0(t3)
    li t3, PLIC + PLIC_THRESH1
    sw zero, 0(t3)
    mv ra, a5
    ret
.endm
