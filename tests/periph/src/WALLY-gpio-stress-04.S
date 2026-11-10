///////////////////////////////////////////
// WALLY-gpio-stress-04.S
//
// Purpose: GPIO interrupt output through the PLIC (source PLIC_GPIO_ID = 3): the request follows
//          OR(ip & ie) for each interrupt type (17.4: "If the corresponding bit in rise_ip or fall_ip is
//          set, an interrupt pin is raised"), enables without pending bits and pending bits without
//          enables raise nothing, clearing the pending bit or the enable drops the request, level types
//          request again while their condition holds, types combine, and every pin can interrupt.
//          Wally ORs all pins into one PLIC source (the FE310 has one per pin); the PLIC gateway keeps a
//          request pending until it is claimed.
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

// Check that the GPIO interrupt is (\on = 1) or is not (\on = 0) pending in the PLIC and at mip.MEIP.
.macro CHK_INT on
    SETTLE
    CHK_PLIC_PEND \on
    CHK_MEIP (\on * MIP_MEIP)
.endm

// Claim (expecting source \id; 0 = nothing pending) and complete.
.macro CLAIM id
    li t3, PLIC_CLAIM0
    lw t4, 0(t3)
    SIGRX t4, \id
    sw t4, 0(t3)
.endm

// Claim (expecting \id), check the interrupt is no longer pending while it is in progress, and leave it
// claimed; COMPLETE finishes it.
.macro CLAIM_ONLY id
    li t3, PLIC_CLAIM0
    lw t4, 0(t3)
    SIGRX t4, \id
.endm
.macro COMPLETE id
    li t3, PLIC_CLAIM0
    li t4, \id
    sw t4, 0(t3)
.endm

// Drive the pins to \val and wait for the synchronizer.
.macro PINS val
    GW GPIO_OUTPUT_VAL, \val
    SETTLE
.endm

INIT_TESTS

TRAP_HANDLER m

GPIO_TEST_BEGIN

// GPIO: all pins inputs and outputs through the loopback, driven low; nothing enabled or pending.
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_OUTPUT_EN, 0xFFFFFFFF
    GW GPIO_INPUT_EN, 0xFFFFFFFF
    SETTLE
    CLEAR_IP
// PLIC: only the GPIO source enabled, for machine mode; supervisor context masked.
    li t3, PLIC_THRESH0
    sw zero, 0(t3)
    li t3, PLIC_THRESH1
    li t2, 7
    sw t2, 0(t3)
    li t3, PLIC_PRI_GPIO
    sw t2, 0(t3)
    li t3, PLIC_EN1
    sw zero, 0(t3)
    li t3, PLIC_EN0
    li t2, (1 << GPIO_IRQ)
    sw t2, 0(t3)
    PLIC_DRAIN
    CHK_INT 0                       // 0-1: low_ip is set on every pin, but low_ie = 0

// ---------------- Enables without pending bits ----------------
    GW GPIO_RISE_IE, 0xFFFFFFFF
    GW GPIO_FALL_IE, 0xFFFFFFFF
    GW GPIO_HIGH_IE, 0xFFFFFFFF     // pins low: no high_ip
    CHK_INT 0
    GW GPIO_RISE_IE, 0
    GW GPIO_FALL_IE, 0
    GW GPIO_HIGH_IE, 0

// ---------------- Rise ----------------
    GW GPIO_RISE_IE, 0x00000080
    PINS 0x00000100                 // a rise on pin 8 only: not enabled
    CHK_INT 0
    PINS 0x00000180                 // rise on pin 7
    CHK_INT 1
    CLAIM_ONLY GPIO_IRQ
    CHK_INT 0                       // claimed: no longer pending
    COMPLETE GPIO_IRQ
    CHK_INT 1                       // rise_ip[7] still set: the request is forwarded again
    GW GPIO_RISE_IP, 0x00000080     // clear it: the request drops, the PLIC still holds it
    CHK_INT 1
    CLAIM GPIO_IRQ
    CHK_INT 0
    CLAIM_ONLY 0                    // nothing else pending (claim returns 0)
    // pending bit with the enable cleared
    GW GPIO_RISE_IE, 0x00000100     // rise_ip[8] is still set from above
    CHK_INT 1
    GW GPIO_RISE_IE, 0
    PLIC_DRAIN
    CHK_INT 0
    GW GPIO_RISE_IE, 0x00000100
    CHK_INT 1                       // re-enabling raises it again
    GW GPIO_RISE_IE, 0
    PLIC_DRAIN
    CLEAR_IP

// ---------------- Fall ----------------
    GW GPIO_FALL_IE, 0x00000080
    PINS 0x00000080                 // pin 8 falls (not enabled), pin 7 stays high
    CHK_INT 0
    PINS 0x00000000                 // pin 7 falls
    CHK_INT 1
    CLAIM_ONLY GPIO_IRQ
    CHK_INT 0
    COMPLETE GPIO_IRQ
    CHK_INT 1
    GW GPIO_FALL_IP, 0xFFFFFF7F     // clearing the other pins leaves pin 7 requesting
    PLIC_DRAIN
    CHK_INT 1
    GW GPIO_FALL_IP, 0x00000080
    PLIC_DRAIN
    CHK_INT 0
    GW GPIO_FALL_IE, 0
    CLEAR_IP

// ---------------- High (level) ----------------
    GW GPIO_HIGH_IE, 0x00000080
    PINS 0x00000100                 // pin 8 high: not enabled
    CHK_INT 0
    PINS 0x00000080                 // pin 7 high
    CHK_INT 1
    GW GPIO_HIGH_IP, 0x00000080     // cleared, but the pin is still high: set again
    PLIC_DRAIN
    CHK_INT 1
    PINS 0x00000000                 // pin low: high_ip stays set until written
    PLIC_DRAIN
    CHK_INT 1
    GW GPIO_HIGH_IP, 0x00000080
    PLIC_DRAIN
    CHK_INT 0
    GW GPIO_HIGH_IE, 0
    CLEAR_IP

// ---------------- Low (level) ----------------
    PINS 0xFFFFFFFF
    CLEAR_IP
    GW GPIO_LOW_IE, 0x00000080
    PLIC_DRAIN
    CHK_INT 0                       // all pins high: no low_ip
    PINS 0xFFFFFEFF                 // pin 8 low: not enabled
    CHK_INT 0
    PINS 0xFFFFFE7F                 // pin 7 low
    CHK_INT 1
    GW GPIO_LOW_IP, 0x00000080      // condition persists: set again
    PLIC_DRAIN
    CHK_INT 1
    PINS 0xFFFFFFFF
    GW GPIO_LOW_IP, 0x00000080
    PLIC_DRAIN
    CHK_INT 0
    GW GPIO_LOW_IE, 0
    PINS 0
    CLEAR_IP
    PLIC_DRAIN

// ---------------- Types combined on one pin ----------------
    GW GPIO_RISE_IE, 0x00000008
    GW GPIO_HIGH_IE, 0x00000008
    PINS 0x00000008                 // rise and high on pin 3
    CHK GPIO_RISE_IP, 0x00000008
    CHK GPIO_HIGH_IP, 0x00000008
    CHK_INT 1
    GW GPIO_RISE_IP, 0x00000008     // rise cleared, high still requests
    PLIC_DRAIN
    CHK_INT 1
    GW GPIO_HIGH_IE, 0              // high disabled: nothing left
    PLIC_DRAIN
    CHK_INT 0
    GW GPIO_FALL_IE, 0x00000008
    GW GPIO_LOW_IE, 0x00000008
    PINS 0                          // fall and low on pin 3
    CHK_INT 1
    GW GPIO_LOW_IE, 0
    PLIC_DRAIN
    CHK_INT 1                       // fall_ip still requests
    GW GPIO_FALL_IP, 0x00000008
    PLIC_DRAIN
    CHK_INT 0
    GW GPIO_FALL_IE, 0
    GW GPIO_RISE_IE, 0
    CLEAR_IP
    PLIC_DRAIN

// ---------------- Every pin can interrupt ----------------
// For each pin i: with rise_ie = 1 << i, a rise on another pin raises nothing, a rise on pin i raises
// the GPIO source (claim ID 3); likewise low_ie = 1 << i with every pin but one high.  Masks of the pins
// that behaved: a0 no false interrupt (rise), a1 interrupt (rise), a2 claim ID 3 (rise), a3 no false
// interrupt (low), a4 interrupt (low).
    jal ra, pin_int_walk
    SIGRX a0, 0xFFFFFFFF
    SIGRX a1, 0xFFFFFFFF
    SIGRX a2, 0xFFFFFFFF
    SIGRX a3, 0xFFFFFFFF
    SIGRX a4, 0xFFFFFFFF
    CHK_INT 0

    GW GPIO_OUTPUT_EN, 0
    GW GPIO_INPUT_EN, 0
    SETTLE
    CLEAR_IP
    li t3, PLIC_EN0
    sw zero, 0(t3)

GPIO_TEST_END

// int_on: a5 = 1 if mip.MEIP is set (after the pins settle).  Uses t2.
int_on:
    SETTLE
    csrr t2, mip
    srli t2, t2, 11
    andi a5, t2, 1
    ret

// pin_int_walk: see "Every pin can interrupt".  Uses a0-a5, s1-s4, t2-t6.
pin_int_walk:
    mv s1, ra
    li a0, 0
    li a1, 0
    li a2, 0
    li a3, 0
    li a4, 0
    li s2, 1                // 1 << i
    li s3, 32
1:
#if __riscv_xlen == 64
    addiw s2, s2, 0
#endif
    // the other pin: i+1 (pin 0 for i = 31)
    slli s4, s2, 1
    bnez s4, 2f
    li s4, 1
2:
    // rise
    sw zero, GPIO_OUTPUT_VAL(s0)
    SETTLE
    CLEAR_IP
    jal ra, gpio_plic_drain
    sw s2, GPIO_RISE_IE(s0)
    sw s4, GPIO_OUTPUT_VAL(s0)
    jal ra, int_on
    bnez a5, 3f
    or a0, a0, s2
3:
    or t5, s4, s2
    sw t5, GPIO_OUTPUT_VAL(s0)
    jal ra, int_on
    beqz a5, 4f
    or a1, a1, s2
4:
    li t3, PLIC_CLAIM0
    lw t4, 0(t3)
    sw t4, 0(t3)
    li t2, GPIO_IRQ
    bne t4, t2, 5f
    or a2, a2, s2
5:
    sw zero, GPIO_RISE_IE(s0)
    // low: all pins high, then the other pin low, then pin i low
    li t5, -1
    sw t5, GPIO_OUTPUT_VAL(s0)
    SETTLE
    CLEAR_IP
    jal ra, gpio_plic_drain
    sw s2, GPIO_LOW_IE(s0)
    not t5, s4
    sw t5, GPIO_OUTPUT_VAL(s0)
    jal ra, int_on
    bnez a5, 6f
    or a3, a3, s2
6:
    not t5, s4
    not t6, s2
    and t5, t5, t6
    sw t5, GPIO_OUTPUT_VAL(s0)
    jal ra, int_on
    beqz a5, 7f
    or a4, a4, s2
7:
    sw zero, GPIO_LOW_IE(s0)
    slli s2, s2, 1
    addi s3, s3, -1
    bnez s3, 1b
    sw zero, GPIO_OUTPUT_VAL(s0)
    SETTLE
    CLEAR_IP
    jal ra, gpio_plic_drain
    mv ra, s1
    ret

GPIO_HELPERS

TEST_STACK_AND_DATA
