///////////////////////////////////////////
// WALLY-gpio.h
//
// Purpose: GPIO register map, signature macros, and helper routines shared by the WALLY-gpio-stress-*
//          peripheral tests.  The expected values in those tests follow the SiFive FE310-G002 Manual,
//          Chapter 17 "General Purpose Input/Output Controller" (v19p05 Table 52, v1p4 Table 50 for
//          iof_en/iof_sel), cited by section, rather than the current RTL.  Where Wally deliberately
//          departs from the FE310 (documented in the RTL or the configuration), the test says so and
//          expects the Wally behavior.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// Test environment
//   The testbench ties GPIOIN to 0.  rv32gc and rv64gc set GPIO_LOOPBACK_TEST, so a pin whose
//   output_en bit is set reads back its own output (after out_xor and the IOF mux); a pin with
//   output_en clear reads GPIOIN = 0.  input_val and the interrupt logic see the pin gated by input_en.
//   Wally's IOF0 on pins 3:0 is PWMGPIO[3:0] (pwm_apb); no other pin has an IOF.
//   Wally ORs all 32 pins into one PLIC source (PLIC_GPIO_ID = 3); the FE310 has one source per pin.
//   Machine interrupts stay disabled (mstatus.MIE = 0): the tests read mip.MEIP and the PLIC pending bits.
//
// Expected values
//   Each check gives its expected value inline (CHK, SIGRX, EXPECT_TRAP ...).  The macros append the value
//   to the .expsig section, which forms the expected_signature table that SIG_NEXT compares against, and
//   the address of the check to .chkpc (not loaded), so entry N of a SELFCHECK MISMATCH report can be
//   mapped back to its source line (entry N is the Nth XLEN-bit word of .chkpc).  All values are 32-bit
//   and are sign extended on RV64 (SEXT32), matching lw and the sext.w in SIGR.  Checks must therefore
//   appear in the source in execution order: no checks inside subroutines or run-time loops.
//
// Register use (besides those the test library reserves: t1, a6, s9-s11, sp, tp):
//   s0     GPIO base address
//   s1-s8  free for the tests; preserved by the helpers
//   a0-a5, t0, t2-t6, ra: arguments and scratch; clobbered by the helpers

.equ GPIO,             0x10060000
.equ GPIO_INPUT_VAL,   0x00
.equ GPIO_INPUT_EN,    0x04
.equ GPIO_OUTPUT_EN,   0x08
.equ GPIO_OUTPUT_VAL,  0x0C
.equ GPIO_PUE,         0x10   // FE310 pull-up enable: not implemented by Wally (gpio_apb.sv header)
.equ GPIO_DS,          0x14   // FE310 drive strength: not implemented by Wally (gpio_apb.sv header)
.equ GPIO_RISE_IE,     0x18
.equ GPIO_RISE_IP,     0x1C
.equ GPIO_FALL_IE,     0x20
.equ GPIO_FALL_IP,     0x24
.equ GPIO_HIGH_IE,     0x28
.equ GPIO_HIGH_IP,     0x2C
.equ GPIO_LOW_IE,      0x30
.equ GPIO_LOW_IP,      0x34
.equ GPIO_IOF_EN,      0x38
.equ GPIO_IOF_SEL,     0x3C
.equ GPIO_OUT_XOR,     0x40
.equ GPIO_PASSTHRU_HI, 0x44   // FE310 v1p4 only (not in v19p05, which Wally follows)
.equ GPIO_PASSTHRU_LO, 0x48

.equ PWM,              0x10020000
.equ PWM_CFG,          0x00
.equ PWM_CMP0,         0x20

.equ PLIC,             0x0C000000
.equ PLIC_PRI_GPIO,    0x0C00000C   // priority of source 3
.equ PLIC_PENDING0,    0x0C001000
.equ PLIC_EN0,         0x0C002000   // context 0 (M) enables
.equ PLIC_EN1,         0x0C002080   // context 1 (S) enables
.equ PLIC_THRESH0,     0x0C200000
.equ PLIC_CLAIM0,      0x0C200004
.equ PLIC_THRESH1,     0x0C201000
.equ GPIO_IRQ,         3
.equ MIP_MEIP,         0x800

// Start the expected-value table.  Place once, right after TRAP_HANDLER.
.macro GPIO_TEST_BEGIN
    .pushsection .expsig, "aw", @progbits
    .align REGSHIFT
expected_signature:
    .popsection
    li s0, GPIO
.endm

// End the test: the final ecall in terminate_test records mcause 0xB.
.macro GPIO_TEST_END
    EXP 0xB
    j terminate_test
    .pushsection .expsig, "aw", @progbits
expected_signature_end:
    .popsection
.endm

// Append expected value \val (a 32-bit value, sign extended on RV64) to the expected signature.
.macro EXP val
    .pushsection .expsig, "aw", @progbits
    WORD SEXT32(\val)
    .popsection
    .pushsection .chkpc, "", @progbits
    WORD chkpc_\@
    .popsection
chkpc_\@:
.endm

// Append register \reg, sign extended from 32 bits, to the signature and check it against \val.
.macro SIGRX reg, val
    EXP \val
#if __riscv_xlen == 64
    addiw t2, \reg, 0
#else
    mv t2, \reg
#endif
    SREG t2, 0(t1)
    SIG_NEXT
.endm

// Read GPIO register \off and check it against \val.
.macro CHK off, val
    EXP \val
    lw t2, \off(s0)
    SREG t2, 0(t1)
    SIG_NEXT
.endm

// Write constant \val to GPIO register \off.
.macro GW off, val
    li t2, \val
    sw t2, \off(s0)
.endm

// Write register \reg to GPIO register \off.
.macro GWR off, reg
    sw \reg, \off(s0)
.endm

// Run \instr, which must trap with mcause \cause (the trap handler records mcause and skips it).
.macro EXPECT_TRAP cause, instr:vararg
    EXP \cause
    \instr
.endm

// Check mip & MEIP against \val.
.macro CHK_MEIP val
    csrr t2, mip
    li t3, MIP_MEIP
    and t2, t2, t3
    SIGRX t2, \val
.endm

// Check the PLIC pending bit of the GPIO source (bit 3 of pending0, as 0 or 1) against \val.
.macro CHK_PLIC_PEND val
    li t3, PLIC_PENDING0
    lw t2, 0(t3)
    srli t2, t2, GPIO_IRQ
    andi t2, t2, 1
    SIGRX t2, \val
.endm

// Wait long enough for a pin change to pass the input synchronizer and reach input_val and the *_ip
// bits (17.4: inputs are synchronized; the latency is not specified).
.macro SETTLE
    .rept 12
    nop
    .endr
.endm

// Clear every pending bit (W1C, 17.4).  Level bits whose condition holds set again at once.
.macro CLEAR_IP
    li t2, -1
    sw t2, GPIO_RISE_IP(s0)
    sw t2, GPIO_FALL_IP(s0)
    sw t2, GPIO_HIGH_IP(s0)
    sw t2, GPIO_LOW_IP(s0)
.endm

// Claim and complete one M-mode PLIC interrupt, if any is pending (the tests enable only the GPIO
// source).  Uses t2, t3.
.macro PLIC_DRAIN
    jal ra, gpio_plic_drain
.endm

// Helper routines.  Place GPIO_HELPERS once in each test, after GPIO_TEST_END.
.macro GPIO_HELPERS

// gpio_nops: execute exactly a0 nops (0 <= a0 < 64) by jumping into a nop sled.  Uses t2, t3.
gpio_nops:
    la t2, gpio_nop_sled_end
    slli t3, a0, 2
    sub t2, t2, t3
    jr t2
gpio_nop_sled:
    .rept 64
    nop
    .endr
gpio_nop_sled_end:
    ret

// gpio_plic_drain: claim and complete one M-mode PLIC interrupt, if any is pending.  Not a loop: a
// level request that persists is pending again right after its completion.  Uses t2, t3.
gpio_plic_drain:
    li t3, PLIC_CLAIM0
    lw t2, 0(t3)
    beqz t2, 1f
    sw t2, 0(t3)
1:
    ret
.endm
