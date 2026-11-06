///////////////////////////////////////////
// WALLY-pwm.h
//
// Purpose: PWM register map, signature macros, and helper routines shared by the WALLY-pwm-stress-*
//          peripheral tests.  The expected values in those tests follow the SiFive FE310-G002 Manual
//          v1p4, chapter 20 (Pulse Width Modulator), cited by section, rather than the current RTL.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// The tests run with machine interrupts disabled and poll the PWM, the GPIO input pins, mip, and the
// PLIC.  The PWM outputs pwm0gpio-pwm3gpio drive GPIO pins 0-3 through iof0; the testbench ties GPIOIN
// to 0, so the pins are observed through the GPIO loopback, which needs input_en and output_en.
//
// Register use (besides those the test library reserves: t1, a6, s9-s11, sp, tp):
//   s0     PWM base address
//   s1     GPIO base address
//   s2-s8  free for the tests; preserved by the helpers
//   a0-a5, t2-t6, ra: arguments and scratch, clobbered by the helpers
//
// Expected signature values are written next to each check with EXPECT, which appends to the
// expected_signature table in .data subsection 2 (opened by EXPECT_BEGIN, closed by EXPECT_END).

.equ PWM,        0x10020000
.equ PWM_CFG,    0x00
.equ PWM_COUNT,  0x08
.equ PWM_S,      0x10
.equ PWM_CMP0,   0x20
.equ PWM_CMP1,   0x24
.equ PWM_CMP2,   0x28
.equ PWM_CMP3,   0x2C

// pwmcfg fields (FE310 Table 89)
.equ CFG_STICKY,   0x00000100
.equ CFG_ZEROCMP,  0x00000200
.equ CFG_DEGLITCH, 0x00000400
.equ CFG_ALWAYS,   0x00001000
.equ CFG_ONESHOT,  0x00002000
.equ CFG_CENTER0,  0x00010000
.equ CFG_GANG0,    0x01000000
.equ CFG_IP0,      0x10000000

.equ GPIO,            0x10060000
.equ GPIO_INPUT_VAL,  0x00
.equ GPIO_INPUT_EN,   0x04
.equ GPIO_OUTPUT_EN,  0x08
.equ GPIO_OUTPUT_VAL, 0x0C
.equ GPIO_RISE_IP,    0x1C
.equ GPIO_FALL_IP,    0x24
.equ GPIO_HIGH_IP,    0x2C
.equ GPIO_IOF_EN,     0x38
.equ GPIO_IOF_SEL,    0x3C
.equ GPIO_OUT_XOR,    0x40

.equ PLIC_PRI,       0x0C000000  // priority of source n at PLIC_PRI + 4n
.equ PLIC_PENDING0,  0x0C001000  // pending bits of sources 31:0
.equ PLIC_EN0,       0x0C002000  // machine-mode enables of sources 31:0
.equ PLIC_EN1,       0x0C002080  // supervisor-mode enables of sources 31:0
.equ PLIC_THRESH0,   0x0C200000
.equ PLIC_CLAIM0,    0x0C200004
.equ PLIC_THRESH1,   0x0C201000
.equ PWM_IRQ0,       11          // pwmcmp0ip..pwmcmp3ip are PLIC sources 11..14

#if __riscv_xlen == 64
#define LWU lwu
#else
#define LWU lw
#endif

// Expected-signature table.  EXPECT_BEGIN once before the first EXPECT, EXPECT_END once after the last.
.macro EXPECT_BEGIN
    .pushsection .data, 2
    .align REGSHIFT
expected_signature:
    .popsection
.endm

.macro EXPECT_END
    .pushsection .data, 2
expected_signature_end:
    .popsection
.endm

.macro EXPECT val
    .pushsection .data, 2
    WORD \val
    .popsection
.endm

// Append register \reg to the signature and check it against the next expected value.
.macro SIGR reg
    SREG \reg, 0(t1)
    SIG_NEXT
.endm

// Write constant \val to PWM register \off.
.macro PW off, val
    li t2, \val
    sw t2, \off(s0)
.endm

// Read PWM register \off (zero extended) into t2.
.macro PR off
    LWU t2, \off(s0)
.endm

// Read PWM register \off (zero extended) into the signature; expect \exp.
.macro CHK off, exp
    LWU t2, \off(s0)
    SIGR t2
    EXPECT \exp
.endm

// Read PWM register \off, keep the bits in \mask, and append the result; expect \exp.
.macro CHKM off, mask, exp
    LWU t2, \off(s0)
    li t3, \mask
    and t2, t2, t3
    SIGR t2
    EXPECT \exp
.endm

// Append the pending bits pwmcmp3ip..pwmcmp0ip (pwmcfg[31:28]) as a 4-bit value; expect \exp.
.macro CHKIP exp
    LWU t2, PWM_CFG(s0)
    srli t2, t2, 28
    SIGR t2
    EXPECT \exp
.endm

// Append register \reg (a computed result); expect \exp.
.macro CHKR reg, exp
    SIGR \reg
    EXPECT \exp
.endm

// Append the four PWM GPIO pins (GPIO input_val[3:0]) after letting them through the 3-flop input
// synchronizer; expect \exp.
.macro CHKPINS exp
    li a0, 12
    jal ra, pwm_delay
    lw t2, GPIO_INPUT_VAL(s1)
    andi t2, t2, 0xF
    SIGR t2
    EXPECT \exp
.endm

// Wait \n cycles (mcycle).
.macro DELAY n
    li a0, \n
    jal ra, pwm_delay
.endm

// Execute exactly \reg nops (0 <= \reg < 1024).
.macro NOPS reg
    mv a0, \reg
    jal ra, pwm_nops
.endm

// Return the PWM to a known idle state.
.macro QUIESCE
    jal ra, pwm_quiesce
.endm

// Expect a trap: the trap handler appends mcause \cause and skips the instruction.
.macro EXPECT_TRAP cause
    EXPECT \cause
.endm

// Helper routines.  Place PWM_HELPERS once in each test, after END_TESTS.
.macro PWM_HELPERS

// pwm_delay: wait a0 cycles (mcycle).  Uses t2, t3.
pwm_delay:
    csrr t2, mcycle
1:
    csrr t3, mcycle
    sub t3, t3, t2
    bltu t3, a0, 1b
    ret

// pwm_nops: execute exactly a0 nops (0 <= a0 < 1024) by jumping into a nop sled.  Uses t2, t3.
pwm_nops:
    la t2, pwm_nop_sled_end
    slli t3, a0, 2
    sub t2, t2, t3
    jr t2
pwm_nop_sled:
    .rept 1024
    nop
    .endr
pwm_nop_sled_end:
    ret

// pwm_quiesce: stop the counter, clear every pwmcfg field and pending bit, set the compare registers
// to all ones and the count to zero, so every comparator output is low.  Uses t2.
pwm_quiesce:
    sw zero, PWM_CFG(s0)
    li t2, 0xFFFF
    sw t2, PWM_CMP0(s0)
    sw t2, PWM_CMP1(s0)
    sw t2, PWM_CMP2(s0)
    sw t2, PWM_CMP3(s0)
    sw zero, PWM_COUNT(s0)
    sw zero, PWM_CFG(s0)   // clear any pending bit the old compare values set
    ret

// pwm_gpio_setup: route the four PWM outputs to GPIO pins 0-3 (iof0) and loop them back.  Uses t2.
pwm_gpio_setup:
    li t2, 0xF
    sw t2, GPIO_IOF_EN(s1)
    sw zero, GPIO_IOF_SEL(s1)
    sw zero, GPIO_OUT_XOR(s1)
    sw t2, GPIO_INPUT_EN(s1)
    sw t2, GPIO_OUTPUT_EN(s1)
    ret

// pwm_plic_setup: PWM sources 11-14 at priority 1, enabled for machine mode only; threshold 0.
// Other sources are disabled.  Uses t2, t3.
pwm_plic_setup:
    li t3, PLIC_THRESH0
    sw zero, 0(t3)
    li t3, PLIC_THRESH1
    li t2, 7
    sw t2, 0(t3)
    li t3, PLIC_PRI + 4*PWM_IRQ0
    li t2, 1
    sw t2, 0(t3)
    sw t2, 4(t3)
    sw t2, 8(t3)
    sw t2, 12(t3)
    li t3, PLIC_EN0
    li t2, (0xF << PWM_IRQ0)
    sw t2, 0(t3)
    li t3, PLIC_EN1
    sw zero, 0(t3)
    ret

// pwm_plic_drain: claim and complete machine-mode PLIC interrupts until none is pending.  Uses t2, t3.
pwm_plic_drain:
    li t3, PLIC_CLAIM0
1:
    lw t2, 0(t3)
    beqz t2, 2f
    sw t2, 0(t3)
    j 1b
2:
    ret

// pwm_plic_claim: a0 = ID claimed from the machine-mode context (0 if none), completing it.  Uses t3.
pwm_plic_claim:
    li t3, PLIC_CLAIM0
    lw a0, 0(t3)
    beqz a0, 1f
    sw a0, 0(t3)
1:
    ret

.endm
