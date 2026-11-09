///////////////////////////////////////////
// WALLY-gpio-stress-03.S
//
// Purpose: GPIO interrupt pending bits: rise/fall/high/low pending set without enables, write-1-to-clear
//          semantics (0 does not clear, 1 clears only its bit, level conditions set again), every pin
//          independently, edges caused by input_en, and an edge arriving in the same cycle as a write
//          to the pending register.
//          Expected values follow the FE310-G002 Manual, Chapter 17 (see WALLY-gpio.h): 17.4 "Once the
//          interrupt is pending, it will remain set until a 1 is written to the *_ip register at that
//          bit", and Figure 9, where each *_ip flop ORs in its condition every cycle and input_en gates
//          the pad input ahead of the synchronizer.
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

// Check all four pending registers.
.macro CHK_IP rip, fip, hip, lip
    CHK GPIO_RISE_IP, \rip
    CHK GPIO_FALL_IP, \fip
    CHK GPIO_HIGH_IP, \hip
    CHK GPIO_LOW_IP,  \lip
.endm

// Same-cycle sweep: a1 = 0 for a rising edge on pin 0 / 1 for a falling edge, a2 = value written to the
// pending register of that edge type.  Result in a0 (see edge_sweep; fall = 2: one-cycle
// high pulse and high_ip).
.macro SWEEP fall, wval
    li a1, \fall
    li a2, \wval
    jal ra, edge_sweep
.endm

INIT_TESTS

TRAP_HANDLER m

GPIO_TEST_BEGIN

// All pins inputs and outputs through the loopback, driven low.
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_OUTPUT_EN, 0xFFFFFFFF
    GW GPIO_INPUT_EN, 0xFFFFFFFF
    SETTLE
    CLEAR_IP
    SETTLE
    CHK_IP 0, 0, 0, 0xFFFFFFFF      // 0..3: low pins: low_ip set again at once

// ---------------- Rising edges on all pins (no interrupt enables) ----------------
    GW GPIO_OUTPUT_VAL, 0xFFFFFFFF
    SETTLE
    CHK_IP 0xFFFFFFFF, 0, 0xFFFFFFFF, 0xFFFFFFFF  // low_ip stays set until written
    GW GPIO_LOW_IP, 0xFFFFFFFF
    CHK GPIO_LOW_IP, 0              // the pins are high now, so it stays clear
// W1C on an edge bit: writing 0 changes nothing, writing 1 clears only that bit
    GW GPIO_RISE_IP, 0
    CHK GPIO_RISE_IP, 0xFFFFFFFF
    GW GPIO_RISE_IP, 0x00010000
    CHK GPIO_RISE_IP, 0xFFFEFFFF
    GW GPIO_RISE_IP, 0x00010000     // clearing a clear bit
    CHK GPIO_RISE_IP, 0xFFFEFFFF
    GW GPIO_RISE_IP, 0x80000001
    CHK GPIO_RISE_IP, 0x7FFEFFFE
    GW GPIO_RISE_IP, 0x5A5A5A5A
    CHK GPIO_RISE_IP, 0x25A4A5A4
    GW GPIO_RISE_IP, 0xFFFFFFFF
    CHK GPIO_RISE_IP, 0
// walking W1C over a full rise_ip: bit i written, bits i..0 now clear
    GW GPIO_OUTPUT_VAL, 0
    SETTLE
    GW GPIO_OUTPUT_VAL, 0xFFFFFFFF
    SETTLE
    CHK GPIO_RISE_IP, 0xFFFFFFFF
    li a0, GPIO_RISE_IP
    jal ra, w1c_walk
    SIGRX a0, 0xFFFFFFFF
// W1C on a level bit whose condition persists: set again at once
    GW GPIO_HIGH_IP, 0
    CHK GPIO_HIGH_IP, 0xFFFFFFFF
    GW GPIO_HIGH_IP, 0xFFFFFFFF
    CHK GPIO_HIGH_IP, 0xFFFFFFFF
    GW GPIO_HIGH_IP, 0x0000FFFF
    CHK GPIO_HIGH_IP, 0xFFFFFFFF
    CHK GPIO_FALL_IP, 0xFFFFFFFF    // from the low pulse before the walk; untouched by the other writes

// ---------------- Falling edges on all pins ----------------
    GW GPIO_FALL_IP, 0xFFFFFFFF
    CHK GPIO_FALL_IP, 0
    GW GPIO_OUTPUT_VAL, 0
    SETTLE
    CHK_IP 0, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
    GW GPIO_HIGH_IP, 0xFFFFFFFF
    CHK GPIO_HIGH_IP, 0
    GW GPIO_LOW_IP, 0xFFFFFFFF
    CHK GPIO_LOW_IP, 0xFFFFFFFF
    GW GPIO_FALL_IP, 0
    CHK GPIO_FALL_IP, 0xFFFFFFFF
    li a0, GPIO_FALL_IP
    jal ra, w1c_walk
    SIGRX a0, 0xFFFFFFFF
    CHK_IP 0, 0, 0, 0xFFFFFFFF

// ---------------- Mixed pattern ----------------
    GW GPIO_OUTPUT_VAL, 0x00FF00FF
    SETTLE
    GW GPIO_OUTPUT_VAL, 0x0F0F0F0F
    SETTLE
    // rises: 0x00FF00FF, then 0x0F000F00; falls: 0x00F000F0; high seen on 0x0FFF0FFF
    CHK_IP 0x0FFF0FFF, 0x00F000F0, 0x0FFF0FFF, 0xFFFFFFFF
    CLEAR_IP
    CHK_IP 0, 0, 0x0F0F0F0F, 0xF0F0F0F0

// ---------------- Every pin on its own ----------------
// For each pin alone: rise -> rise_ip and high_ip = that pin only; after clearing low_ip it is set on
// every other pin; fall -> fall_ip = that pin only.  Four masks of the pins that behaved.
    GW GPIO_OUTPUT_VAL, 0
    SETTLE
    jal ra, pin_walk
    SIGRX a0, 0xFFFFFFFF            // rise_ip
    SIGRX a1, 0xFFFFFFFF            // high_ip
    SIGRX a2, 0xFFFFFFFF            // low_ip
    SIGRX a3, 0xFFFFFFFF            // fall_ip

// ---------------- Edges caused by input_en (Figure 9: input_en gates the pad input) ----------------
    GW GPIO_INPUT_EN, 0
    GW GPIO_OUTPUT_VAL, 0x0000FFFF
    SETTLE
    CLEAR_IP
    SETTLE
    CHK_IP 0, 0, 0, 0xFFFFFFFF
    GW GPIO_INPUT_EN, 0x000000FF    // pins 7:0 are high: rising edge seen
    SETTLE
    CHK GPIO_INPUT_VAL, 0x000000FF
    CHK_IP 0x000000FF, 0, 0x000000FF, 0xFFFFFFFF
    CLEAR_IP                        // high_ip of pins 7:0 is set again at once
    GW GPIO_INPUT_EN, 0             // disabling the input reads 0: falling edge
    SETTLE
    CHK_IP 0, 0x000000FF, 0x000000FF, 0xFFFFFFFF

// ---------------- An edge in the same cycle as a write to its pending register ----------------
// Only a 1 written to a bit clears it (17.4; Figure 9 ORs the condition into the flop every cycle), so a
// write of 0, or of 1 to other pins, must not lose an edge on this pin in whatever cycle the edge reaches
// the pending logic.  Stores to the GPIO are at least 4 cycles apart and a pin change reaches the
// pending logic 3 cycles after its store, so a store cannot make the edge land on a later store.  The
// edge instead comes from the PWM through IOF0 on pin 0: the store that starts the PWM counter is
// followed (after one spacer store) by the store to the pending register, and the compare value
// C = 1..32 moves the edge one cycle at a time across that store.  Bit C-1 of the result is set if the edge was kept.
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_OUTPUT_EN, 0x00000001
    GW GPIO_INPUT_EN, 0x00000001
    GW GPIO_IOF_SEL, 0
    GW GPIO_IOF_EN, 0x00000001
    SETTLE
    SWEEP 0, 0x00000000             // rise, write 0 to rise_ip
    SIGRX a0, 0xFFFFFFFF
    SWEEP 0, 0x00000200             // rise, clear pin 9 of rise_ip
    SIGRX a0, 0xFFFFFFFF
    SWEEP 0, 0xFFFFFFFE             // rise, clear every other pin of rise_ip
    SIGRX a0, 0xFFFFFFFF
    SWEEP 1, 0x00000000             // fall, write 0 to fall_ip
    SIGRX a0, 0xFFFFFFFF
    SWEEP 1, 0x00000200             // fall, clear pin 9 of fall_ip
    SIGRX a0, 0xFFFFFFFF
// The same holds for a level that lasts a single cycle: the pin is sampled synchronously every cycle
// (17.4), so a one-cycle high pulse sets high_ip, and a write of 0 to high_ip must not lose it.
    SWEEP 2, 0x00000000             // one-cycle high pulse, write 0 to high_ip
    SIGRX a0, 0xFFFFFFFF
    GW GPIO_IOF_EN, 0
    GW GPIO_OUT_XOR, 0
    li t3, PWM
    li t2, 0xFFFF
    sw t2, PWM_CMP0(t3)

    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_OUTPUT_EN, 0
    GW GPIO_INPUT_EN, 0
    SETTLE
    CLEAR_IP

GPIO_TEST_END

// w1c_walk: with every bit of pending register s0 + a0 set (and no condition that sets it again),
// write 1 << i for i = 0..31 and check after each write that exactly bits 31:i+1 remain.  Returns
// a0 = mask of the steps that matched.  Uses a1-a3, t3-t6.
w1c_walk:
    add t4, s0, a0
    li a1, 0
    li t5, 1
    li a2, -1               // expected remaining bits
    li a3, 32
1:
    sw t5, 0(t4)
    xor a2, a2, t5
#if __riscv_xlen == 64
    addiw a2, a2, 0
#endif
    lw t3, 0(t4)
    bne t3, a2, 2f
    or a1, a1, t5
2:
    slli t5, t5, 1
    addi a3, a3, -1
    bnez a3, 1b
    mv a0, a1
    ret

// pin_walk: all pins low and output_val = 0 on entry.  For each pin i: clear all pending bits, raise the
// pin, check rise_ip and high_ip = 1 << i; clear low_ip and check it = ~(1 << i); clear everything,
// lower the pin, check fall_ip = 1 << i.  Returns masks a0 (rise), a1 (high), a2 (low), a3 (fall).
// Uses a4, a5, t2-t6.
pin_walk:
    li a0, 0
    li a1, 0
    li a2, 0
    li a3, 0
    li t5, 1
    li a5, 32
1:
#if __riscv_xlen == 64
    addiw t5, t5, 0         // as lw returns it
#endif
    CLEAR_IP
    sw t5, GPIO_OUTPUT_VAL(s0)
    SETTLE
    lw t3, GPIO_RISE_IP(s0)
    bne t3, t5, 2f
    or a0, a0, t5
2:
    lw t3, GPIO_HIGH_IP(s0)
    bne t3, t5, 3f
    or a1, a1, t5
3:
    li t2, -1
    sw t2, GPIO_LOW_IP(s0)
    not t6, t5
    lw t3, GPIO_LOW_IP(s0)
    bne t3, t6, 4f
    or a2, a2, t5
4:
    CLEAR_IP
    sw zero, GPIO_OUTPUT_VAL(s0)
    SETTLE
    lw t3, GPIO_FALL_IP(s0)
    bne t3, t5, 5f
    or a3, a3, t5
5:
    slli t5, t5, 1
    addi a5, a5, -1
    bnez a5, 1b
    ret

// edge_sweep: pin 0 on IOF0 (PWMGPIO[0]); a1 = 0: rising edge, a1 = 1: falling edge (out_xor[0] = 1
// inverts the PWM output), a1 = 2: a one-cycle high pulse (one-shot PWM ending its cycle at pwmcmp0);
// a2 = value written to rise_ip, fall_ip, or high_ip respectively.  For each
// C = 1..32: stop the PWM with pwmcount = 0 and pwmcmp0 = C (output low), clear the pending bits, then
// set pwmenalways and, after one spacer store, store a2 to the pending register; the PWM output rises
// when the count reaches C.  Bit C-1 of the result is set if pin 0 is pending afterwards.  Each C is run twice
// and only the second run counts, so the code is in the I$.  Returns a0.  Uses a1-a5, s1-s4, t2-t6.
edge_sweep:
    mv s1, ra
    li s3, 0                // result
    li s4, 1                // C
    li a3, PWM
    li a4, 0x1000           // pwmcfg.pwmenalways, scale 0, no zerocmp
    addi a5, s0, GPIO_RISE_IP
    beqz a1, 1f
    li t2, 1
    addi a5, s0, GPIO_FALL_IP
    beq a1, t2, 1f
    addi a5, s0, GPIO_HIGH_IP
    li a4, 0x2200           // pwmcfg.pwmenoneshot | pwmzerocmp: one cycle-long pulse when pwms reaches C
1:
    andi t2, a1, 1
    sw t2, GPIO_OUT_XOR(s0) // inverted output for the falling edge
2:
    li t6, 2                // two runs
3:
    sw zero, PWM_CFG(a3)    // stop the PWM
    sw zero, 8(a3)          // pwmcount = 0
    sw s4, PWM_CMP0(a3)     // output low until pwms >= C
    SETTLE
    CLEAR_IP
    SETTLE
    sw a4, PWM_CFG(a3)      // start counting
    sw zero, GPIO_OUTPUT_VAL(s0)  // spacer (pin 0 is on the IOF): the edge reaches the pending logic
                                  // 5-6 cycles after the PWM store, the next store comes 4 cycles later
    sw a2, 0(a5)            // write to the pending register while the edge comes
    .rept 6
    SETTLE
    .endr
    lw t3, 0(a5)            // read before the PWM stops (stopping makes the opposite edge)
    addi t6, t6, -1
    bnez t6, 3b
    andi t3, t3, 1
    beqz t3, 4f
    li t2, 1
    addi t5, s4, -1
    sll t2, t2, t5
    or s3, s3, t2
4:
    addi s4, s4, 1
    li t2, 33
    bne s4, t2, 2b
    sw zero, PWM_CFG(a3)
    sw zero, 8(a3)
    sw zero, GPIO_OUT_XOR(s0)
    SETTLE
    mv a0, s3
    mv ra, s1
    ret

GPIO_HELPERS

TEST_STACK_AND_DATA
