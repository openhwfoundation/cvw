///////////////////////////////////////////
// WALLY-gpio-stress-02.S
//
// Purpose: GPIO pin values through the loopback: input_en gating of input_val, output_en gating of the
//          driven value, output_val independent of output_en, out_xor on software and IOF outputs, and
//          the IOF mux (iof_en, iof_sel), including pins that have no IOF.
//          Expected values follow the FE310-G002 Manual, Chapter 17 (see WALLY-gpio.h).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"
#include "WALLY-gpio.h"

// Write the PWM compare registers: 0 makes every pwmcmpXip (and PWMGPIO[X], Wally's IOF0 on pin X) 1
// with the PWM counter stopped at 0; 0xFFFF makes them 0 (FU540 PWM: pwmcmpXip = pwms >= pwmcmpX).
.macro PWM_OUT val
    li t3, PWM
    li t2, \val
    sw t2, (PWM_CMP0+0)(t3)
    sw t2, (PWM_CMP0+4)(t3)
    sw t2, (PWM_CMP0+8)(t3)
    sw t2, (PWM_CMP0+12)(t3)
    SETTLE
.endm

INIT_TESTS

TRAP_HANDLER m

GPIO_TEST_BEGIN

    PWM_OUT 0xFFFF                  // IOF0 outputs low until a test wants them

// ---------------- input_en gates input_val (17.3) ----------------
// Every pin driven high through the loopback; input_val shows exactly the pins with input_en set.
    GW GPIO_OUTPUT_VAL, 0xFFFFFFFF
    GW GPIO_OUTPUT_EN, 0xFFFFFFFF
    SETTLE
    CHK GPIO_INPUT_VAL, 0           // input_en = 0
    GW GPIO_INPUT_EN, 0xA5A5A5A5
    SETTLE
    CHK GPIO_INPUT_VAL, 0xA5A5A5A5
    GW GPIO_INPUT_EN, 0x5A5A5A5A
    SETTLE
    CHK GPIO_INPUT_VAL, 0x5A5A5A5A
    li a0, GPIO_INPUT_EN
    li a2, 0
    jal ra, walk_pin                // walking one in input_en: input_val = 1 << i
    SIGRX a0, 0xFFFFFFFF
    li a0, GPIO_INPUT_EN
    li a2, -1
    jal ra, walk_pin                // walking zero
    SIGRX a0, 0xFFFFFFFF
    // input_en gates only the input: with all outputs low it shows 0 whatever input_en is
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_INPUT_EN, 0xFFFFFFFF
    SETTLE
    CHK GPIO_INPUT_VAL, 0

// ---------------- output_en gates the driven value (17.3; loopback test configuration) ----------------
// A pin with output_en clear is not driven and reads GPIOIN = 0.
    GW GPIO_OUTPUT_VAL, 0xFFFFFFFF
    GW GPIO_OUTPUT_EN, 0
    SETTLE
    CHK GPIO_INPUT_VAL, 0
    li a0, GPIO_OUTPUT_EN
    li a2, 0
    jal ra, walk_pin                // walking one in output_en
    SIGRX a0, 0xFFFFFFFF
    li a0, GPIO_OUTPUT_EN
    li a2, -1
    jal ra, walk_pin                // walking zero
    SIGRX a0, 0xFFFFFFFF
    GW GPIO_OUTPUT_VAL, 0x3C3C3C3C
    GW GPIO_OUTPUT_EN, 0xFF00FF00
    SETTLE
    CHK GPIO_INPUT_VAL, 0x3C003C00

// ---------------- output_val follows writes regardless of output_en (17.3) ----------------
    GW GPIO_OUTPUT_EN, 0
    GW GPIO_OUTPUT_VAL, 0x13579BDF
    CHK GPIO_OUTPUT_VAL, 0x13579BDF
    SETTLE
    CHK GPIO_INPUT_VAL, 0
    GW GPIO_OUTPUT_EN, 0xFFFFFFFF   // enabling the outputs drives the value written while disabled
    SETTLE
    CHK GPIO_INPUT_VAL, 0x13579BDF
    li a0, GPIO_OUTPUT_VAL
    li a2, 0
    jal ra, walk_pin                // walking one in output_val with every output enabled
    SIGRX a0, 0xFFFFFFFF
    li a0, GPIO_OUTPUT_VAL
    li a2, -1
    jal ra, walk_pin
    SIGRX a0, 0xFFFFFFFF

// ---------------- out_xor inverts the output (17.7) ----------------
    GW GPIO_OUTPUT_VAL, 0
    li a0, GPIO_OUT_XOR
    li a2, 0
    jal ra, walk_pin                // walking one in out_xor over output_val = 0
    SIGRX a0, 0xFFFFFFFF
    li a0, GPIO_OUT_XOR
    li a2, -1
    jal ra, walk_pin
    SIGRX a0, 0xFFFFFFFF
    GW GPIO_OUTPUT_VAL, 0xFFFFFFFF
    GW GPIO_OUT_XOR, 0x0000FFFF
    SETTLE
    CHK GPIO_INPUT_VAL, 0xFFFF0000
    CHK GPIO_OUTPUT_VAL, 0xFFFFFFFF // out_xor does not change the register value
    GW GPIO_OUTPUT_VAL, 0x0F0F0F0F
    GW GPIO_OUT_XOR, 0x00FF00FF
    SETTLE
    CHK GPIO_INPUT_VAL, 0x0FF00FF0
    // an undriven pin is not inverted: out_xor acts on the output only
    GW GPIO_OUTPUT_EN, 0x0000FFFF
    SETTLE
    CHK GPIO_INPUT_VAL, 0x00000FF0
    GW GPIO_OUT_XOR, 0
    GW GPIO_OUTPUT_EN, 0xFFFFFFFF

// ---------------- IOF (17.8) ----------------
// Wally's IOF0 on pins 3:0 is PWMGPIO[3:0].  With iof_en set and iof_sel = 0 those pins follow the PWM,
// not output_val; out_xor still applies (17.7: "either software or IOF controlled").
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_IOF_SEL, 0
    GW GPIO_IOF_EN, 0x0000000F
    SETTLE
    CHK GPIO_INPUT_VAL, 0x00000000  // PWM outputs low
    PWM_OUT 0
    CHK GPIO_INPUT_VAL, 0x0000000F  // PWM outputs high
    GW GPIO_OUT_XOR, 0x00000005
    SETTLE
    CHK GPIO_INPUT_VAL, 0x0000000A  // inverted IOF output
    GW GPIO_OUT_XOR, 0
    GW GPIO_IOF_EN, 0x00000006      // only pins 2:1 on the IOF
    SETTLE
    CHK GPIO_INPUT_VAL, 0x00000006
    GW GPIO_OUTPUT_VAL, 0x00000009  // pins 3 and 0 under software control again
    SETTLE
    CHK GPIO_INPUT_VAL, 0x0000000F
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_IOF_EN, 0               // all software: the PWM no longer reaches the pins
    SETTLE
    CHK GPIO_INPUT_VAL, 0
    CHK GPIO_IOF_EN, 0
    // Wally's IOF does not take over output_en (17.8 lets each IOF choose): an IOF pin with output_en
    // clear is undriven.
    GW GPIO_IOF_EN, 0x0000000F
    GW GPIO_OUTPUT_EN, 0xFFFFFFF0
    SETTLE
    CHK GPIO_INPUT_VAL, 0
    GW GPIO_OUTPUT_EN, 0xFFFFFFFF
    GW GPIO_IOF_EN, 0

// 17.8: "If there is no IOFx for a pin configured with IOFx, the pin reverts to full software control."
// Pins 31:4 have no IOF0 and no pin has an IOF1, so these pins must follow output_val.
    PWM_OUT 0xFFFF                  // IOF0 outputs low, so pins 3:0 on IOF0 read 0
    GW GPIO_OUTPUT_VAL, 0xFFFFFFFF
    GW GPIO_IOF_SEL, 0
    GW GPIO_IOF_EN, 0xFFFFFFFF      // IOF0 everywhere
    SETTLE
    CHK GPIO_INPUT_VAL, 0xFFFFFFF0  // 31:4 software (1), 3:0 PWM (0)
    GW GPIO_OUTPUT_VAL, 0xA5A5A5A5
    SETTLE
    CHK GPIO_INPUT_VAL, 0xA5A5A5A0
    GW GPIO_IOF_SEL, 0xFFFFFFFF     // IOF1 everywhere: no pin has one
    GW GPIO_OUTPUT_VAL, 0xFFFFFFFF
    SETTLE
    CHK GPIO_INPUT_VAL, 0xFFFFFFFF
    GW GPIO_OUTPUT_VAL, 0x5A5A5A5A
    SETTLE
    CHK GPIO_INPUT_VAL, 0x5A5A5A5A
    GW GPIO_IOF_SEL, 0x0000000C     // pins 3:2 on IOF1 (none: software), 1:0 on IOF0 (PWM, low)
    GW GPIO_OUTPUT_VAL, 0x0000000F
    SETTLE
    CHK GPIO_INPUT_VAL, 0x0000000C
    GW GPIO_IOF_EN, 0
    GW GPIO_IOF_SEL, 0
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_OUTPUT_EN, 0
    GW GPIO_INPUT_EN, 0
    PWM_OUT 0

GPIO_TEST_END

// walk_pin: for each of the 32 bits, write a pattern with that bit different from the others (a2 = 0:
// walking one, a2 = -1: walking zero) to GPIO register s0 + a0, wait for the pins to settle, and compare
// input_val with the pattern.  Returns a0 = mask of the bit positions where they matched.  Leaves the
// register 0.  Uses a1, a3, t3-t6.
walk_pin:
    add t4, s0, a0
    li a1, 0
    li t5, 1
    li a3, 32
1:
    xor t6, t5, a2
#if __riscv_xlen == 64
    addiw t6, t6, 0
#endif
    sw t6, 0(t4)
    SETTLE
    lw t3, GPIO_INPUT_VAL(s0)
    bne t3, t6, 2f
    or a1, a1, t5
2:
    slli t5, t5, 1
    addi a3, a3, -1
    bnez a3, 1b
    sw zero, 0(t4)
    mv a0, a1
    ret

GPIO_HELPERS

TEST_STACK_AND_DATA
