///////////////////////////////////////////
// WALLY-pwm-stress-02.S
//
// Purpose: PWM counter stress test with the counter running: counting and stopping, pwmcount writes
//          while running, the pwms carry out at every pwmscale (and at the full 31-bit width), the
//          pwmzerocmp reset (including pwmcmp0 = 0 and a count already past pwmcmp0), pwmcfg writes
//          while running, one-shot cycles at several scales and start points, the one-shot ending
//          while other PWM registers are being written, deglitch and sticky pending bits across PWM
//          cycles, center mode with deglitch, and comparator pulses latched by the PLIC.  Checks are
//          robust to software timing: they sync to the counter, or sweep a store across every cycle
//          of a window.  Expected values follow the SiFive FE310-G002 Manual v1p4, chapter 20.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"
#include "WALLY-pwm.h"

INIT_TESTS

TRAP_HANDLER m

EXPECT_BEGIN

    li s0, PWM
    li s1, GPIO
    jal ra, pwm_gpio_setup
    jal ra, pwm_plic_setup
    QUIESCE
    jal ra, pwm_plic_drain

// Append (a <= reg <= b) as 1 or 0; expect 1.
.macro CHK_RANGE reg, a, b
    li t3, \a
    sltu t4, \reg, t3               // reg < a
    li t3, \b
    sltu t5, t3, \reg               // reg > b
    or t4, t4, t5
    xori t4, t4, 1
    CHKR t4, 1
.endm

// ===================================================================================================
// 1. Counting (20.5): the counter increments by one each cycle while an enable is set, holds when
//    none is, and can be written while running (20.4).
// ===================================================================================================
    PW PWM_CFG, CFG_ALWAYS
    PR PWM_COUNT
    mv s2, t2
    PR PWM_COUNT
    sub t2, t2, s2
    CHK_RANGE t2, 1, 100            // advanced, by about the time between the reads
    PW PWM_CFG, CFG_ALWAYS | 15     // pwmscale 15: no cycle end for a long time
    PW PWM_COUNT, 0x00100000        // write while running
    PR PWM_COUNT
    CHK_RANGE t2, 0x00100000, 0x00100040
    PW PWM_CFG, 15                  // stop
    PR PWM_COUNT
    mv s2, t2
    DELAY 50
    PR PWM_COUNT
    sub t2, t2, s2
    CHKR t2, 0                      // held while stopped
    // pwmcfg writes while running do not disturb the count; pwmscale can change on the fly
    PW PWM_COUNT, 0
    PW PWM_CFG, CFG_ALWAYS
    DELAY 40
    PR PWM_COUNT
    mv s2, t2
    PW PWM_CFG, CFG_ALWAYS | 4
    PR PWM_COUNT
    sub t2, t2, s2
    CHK_RANGE t2, 1, 100            // still counting up from where it was
    PW PWM_CFG, 4                   // stop and check pwms = pwmcount[19:4]
    PR PWM_COUNT
    srli s2, t2, 4
    li t3, 0xFFFF
    and s2, s2, t3
    PR PWM_S
    sub t2, t2, s2
    CHKR t2, 0
    QUIESCE

// ===================================================================================================
// 2. Wrap without pwmzerocmp (20.4, 20.8): "the counter is ... reset to zero at the end of every PWM
//    cycle ... or is simply allowed to wrap around to zero", the end of the cycle being the carry out
//    of the high bit of the pwms incrementer.  For every pwmscale the counter starts 32 counts
//    before that carry, with bit 30 (above pwms, for pwmscale < 15) also set; after the carry the
//    whole counter has wrapped to a small value.
// ===================================================================================================
    .irp s, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    PW PWM_CFG, \s
.if \s < 15
    PW PWM_COUNT, ((1 << 30) | ((1 << (\s + 16)) - 32))
.else
    PW PWM_COUNT, ((1 << (\s + 16)) - 32)
.endif
    PW PWM_CFG, CFG_ALWAYS | \s
    DELAY 200
    PW PWM_CFG, \s
    PR PWM_COUNT
    CHK_RANGE t2, 0, 0x200
    .endr
    QUIESCE

// ===================================================================================================
// 3. pwmzerocmp (20.5, 20.7): pwmcount is reset to zero one cycle after pwms matches (reaches or
//    exceeds) pwmcmp0, so pwmcount never exceeds pwmcmp0 << pwmscale.
// ===================================================================================================
.macro ZC_MAX s, cmp
    PW PWM_CMP0, \cmp
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP | \s
    li s3, 0                        // largest count seen
    li s4, 200                      // samples
1:
    PR PWM_COUNT
    bgeu s3, t2, 2f
    mv s3, t2
2:
    addi s4, s4, -1
    bnez s4, 1b
    QUIESCE
    CHK_RANGE s3, 1, (\cmp << \s)
.endm
    ZC_MAX 0, 0x40
    ZC_MAX 3, 0x40
    ZC_MAX 0, 0x07

    // pwmcmp0 = 0: pwms >= pwmcmp0 always, so the counter is reset every cycle and stays at zero,
    // and pwmcmp0ip is always set
    PW PWM_CMP0, 0
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP
    li s3, 0
    .rept 16
    PR PWM_COUNT
    or s3, s3, t2
    .endr
    CHKR s3, 0
    CHKIP 1
    QUIESCE

    // A count written past pwmcmp0 while running is reset at once ("reaches or exceeds", 20.7)
    PW PWM_CMP0, 0x100
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP
    PW PWM_COUNT, 0x5000
    DELAY 20
    PR PWM_COUNT
    CHK_RANGE t2, 0, 0x100
    // Turning pwmzerocmp on while the count is already past pwmcmp0 resets it too
    PW PWM_CFG, CFG_ALWAYS
    PW PWM_COUNT, 0x5000
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP
    DELAY 20
    PR PWM_COUNT
    CHK_RANGE t2, 0, 0x100
    QUIESCE

    // With the counter stopped.  Figure 11 drives the pwmcount reset input from
    // (pwmzerocmp & comparator 0) | carryout, independent of the enable input, and 20.5 says the reset
    // happens one cycle after pwms matches pwmcmp0.  A count written past pwmcmp0 is therefore cleared
    // even though the counter is not enabled.
    PW PWM_CMP0, 0x10
    PW PWM_CFG, CFG_ZEROCMP
    PW PWM_COUNT, 0x100
    DELAY 20
    CHK PWM_COUNT, 0
    QUIESCE

// ===================================================================================================
// 4. One-shot (20.5, 20.12): the counter runs for one PWM cycle; once the reset condition occurs,
//    pwmenoneshot is cleared and counting stops with pwmcount = 0.
// ===================================================================================================
.macro ONESHOT cfg, count, cmp0, wait
    PW PWM_CMP0, \cmp0
    PW PWM_COUNT, \count
    PW PWM_CFG, CFG_ONESHOT | \cfg
    DELAY \wait
    CHKM PWM_CFG, 0x0FFFFFFF, \cfg  // pwmenoneshot cleared (pending bits not checked)
    CHK PWM_COUNT, 0
    DELAY 100
    CHK PWM_COUNT, 0                // and stays stopped
    QUIESCE
.endm
    ONESHOT CFG_ZEROCMP,     0,     0x80, 600     // period 0x81
    ONESHOT CFG_ZEROCMP | 4, 0,     0x20, 2000    // period (0x20 << 4) + 1
    ONESHOT CFG_ZEROCMP,     0x500, 0x100, 50     // started past pwmcmp0: ends at once
    ONESHOT CFG_ZEROCMP,     0,     0,    50      // pwmcmp0 = 0: one clock
    ONESHOT 3,               ((1 << 19) - 64), 0xFFFF, 500  // no zerocmp, pwmscale 3: ends at the pwms carry
    ONESHOT CFG_ZEROCMP | 15, ((1 << 31) - 64), 0xFFFF, 500 // full-width carry at pwmscale 15

// ===================================================================================================
// 5. The one-shot ends at its reset whatever else software writes (20.5: "pwmenoneshot is reset to
//    zero once the counter resets").  A store to another PWM register is swept across every cycle
//    around the end of a one-shot cycle (pwmcmp0 = 200, pwmscale 0); some store lands on the
//    cycle the counter resets.  Shortly after the end, but well before a second cycle could end,
//    the counter must be stopped at zero with pwmenoneshot clear.  The result is the number of
//    store positions for which it was not (expected 0).
// ===================================================================================================
.macro ONESHOT_SWEEP off
    li s5, 0                        // failures
    li s6, 100                      // nops between the start and the store
1:
    sw zero, PWM_CFG(s0)
    sw zero, PWM_COUNT(s0)
    li t2, 200
    sw t2, PWM_CMP0(s0)
    li s7, 0xFFFF                   // value for the swept store (cmpX are already 0xFFFF)
    li t2, CFG_ONESHOT | CFG_ZEROCMP
    csrr s8, mcycle
    sw t2, PWM_CFG(s0)              // start the one-shot
    NOPS s6
    sw s7, \off(s0)                 // the swept store
    li t2, 330                      // past the end (~200 cycles), before a second end (~400)
    add s8, s8, t2
2:
    csrr t2, mcycle
    bltu t2, s8, 2b
    LWU t2, PWM_COUNT(s0)
    LWU t3, PWM_CFG(s0)
    li t4, CFG_ONESHOT
    and t3, t3, t4
    or t2, t2, t3
    beqz t2, 3f
    addi s5, s5, 1
3:
    addi s6, s6, 1
    li t2, 260
    bltu s6, t2, 1b
    CHKR s5, 0
    QUIESCE
.endm
    ONESHOT_SWEEP PWM_CMP1
    ONESHOT_SWEEP 0x30              // a reserved offset

// ===================================================================================================
// 5b. A pwmcount or pwms write on the cycle the counter resets is not lost.  The spec leaves the
//     priority open; Wally follows SiFive's PWM, where the write wins.  The counter runs from
//     pwmcmp0 - 150 with pwmzerocmp (pwmscale 0), and a store of 0x800 to \off is swept across every
//     cycle around the reset.  Read just after the store, pwmcount must be at least 0x800 (a dropped
//     write leaves it a few counts past 0).  The result is the number of store positions for which it
//     was not (expected 0).
// ===================================================================================================
.macro COUNTWRITE_SWEEP off
    li s5, 0                        // failures
    li s6, 100                      // nops between the start and the store
1:
    sw zero, PWM_CFG(s0)
    li t2, 0x1100
    sw t2, PWM_CMP0(s0)
    li t2, 0x1100 - 150
    sw t2, PWM_COUNT(s0)
    li s7, 0x800                    // value for the swept store
    li t2, CFG_ALWAYS | CFG_ZEROCMP
    sw t2, PWM_CFG(s0)              // start counting
    NOPS s6
    sw s7, \off(s0)                 // the swept store
    LWU t2, PWM_COUNT(s0)
    sw zero, PWM_CFG(s0)            // stop
    li t3, 0x800
    bgeu t2, t3, 3f
    addi s5, s5, 1
3:
    addi s6, s6, 1
    li t2, 260
    bltu s6, t2, 1b
    CHKR s5, 0
    QUIESCE
.endm
    COUNTWRITE_SWEEP PWM_COUNT
    COUNTWRITE_SWEEP PWM_S

// ===================================================================================================
// 6. Deglitch (20.8): with pwmdeglitch a pending bit that has gone high cannot fall again within the
//    same PWM cycle; it changes again at the start of the next cycle.  pwmzerocmp, pwmcmp0 = 0x400.
// ===================================================================================================
.macro WAIT_COUNT_IN lo, hi        // poll until lo <= pwmcount <= hi
1:
    PR PWM_COUNT
    li t3, \lo
    bltu t2, t3, 1b
    li t3, \hi
    bltu t3, t2, 1b
.endm
.macro DEGLITCH_CASE deg, exp_held
    PW PWM_CMP0, 0x400
    PW PWM_CMP1, 0x10
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP | \deg
    WAIT_COUNT_IN 0x40, 0x200       // pwmcmp1ip is high
    PW PWM_CMP1, 0x300              // raise pwmcmp1 above the count
    CHKM PWM_CFG, (CFG_IP0 << 1), (\exp_held << 29)
    WAIT_COUNT_IN 0x301, 0x3F0      // later in the same cycle, past the new pwmcmp1
    WAIT_COUNT_IN 0x40, 0x200       // the next cycle, before pwmcmp1
    CHKM PWM_CFG, (CFG_IP0 << 1), 0 // released at the start of the cycle (or never held)
    WAIT_COUNT_IN 0x310, 0x3F0
    CHKM PWM_CFG, (CFG_IP0 << 1), (CFG_IP0 << 1)
    QUIESCE
.endm
    DEGLITCH_CASE CFG_DEGLITCH, 1
    DEGLITCH_CASE 0, 0

    // Wrap mode with pwmdeglitch at pwmscale 2: the hold is released by the pwms carry out
    PW PWM_CMP1, 0x10
    PW PWM_COUNT, ((1 << 18) - 0x400)   // pwms = 0xFF00
    PW PWM_CFG, CFG_ALWAYS | CFG_DEGLITCH | 2
    DELAY 40
    PW PWM_CMP1, 0xFFF0             // above the count
    CHKM PWM_CFG, (CFG_IP0 << 1), (CFG_IP0 << 1)   // held
    WAIT_COUNT_IN 0x100, 0x3000     // wrapped; pwms is between 0x40 and 0xC00
    CHKM PWM_CFG, (CFG_IP0 << 1), 0 // released by the carry out
    QUIESCE

    // Center mode with pwmdeglitch (20.10): one 0-to-1 transition in the first half of the cycle and
    // one 1-to-0 transition in the second.  The counter is stopped and pwms set directly.
    PW PWM_CFG, (CFG_CENTER0 << 1) | CFG_DEGLITCH
    PW PWM_COUNT, 0x0100            // first half
    PW PWM_CMP1, 0x0100
    CHKIP 2
    PW PWM_CMP1, 0x0200             // comparator low: held in the first half
    CHKIP 2
    PW PWM_COUNT, 0x8100            // second half: pwmscenter = 0x7EFF
    CHKIP 2                         // comparator high again (0x7EFF >= 0x200)
    PW PWM_CMP1, 0x7F00             // comparator low in the second half: allowed to fall
    CHKIP 0
    PW PWM_COUNT, 0x0100            // first half, comparator low (0x100 < 0x7F00)
    CHKIP 0
    QUIESCE

// ===================================================================================================
// 7. Sticky (20.8, 20.13): with pwmsticky, pending bits stay set across PWM cycles until software
//    clears them through pwmcfg.
// ===================================================================================================
    PW PWM_CMP0, 0x100
    PW PWM_CMP1, 0x80
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP | CFG_STICKY
    DELAY 600
    CHKIP 3                         // both comparators fired and stayed set
    PW PWM_CMP1, 0xFFFF             // comparator 1 never fires again
    DELAY 600
    CHKIP 3                         // still set: sticky
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP | CFG_STICKY  // clear the pending bits
    DELAY 600
    CHKIP 1                         // comparator 0 set again at the next cycle end; 1 stays clear
    QUIESCE
    jal ra, pwm_plic_drain

    // Without pwmsticky the pending bits only pulse, but the PLIC latches each comparator's pulse
    // as its own source (20.1, 20.13).
    PW PWM_CMP0, 0x40
    PW PWM_CMP2, 0x20
    PW PWM_CFG, CFG_ALWAYS | CFG_ZEROCMP
    DELAY 300
    PW PWM_CMP2, 0xFFFF             // stop the comparators firing
    PW PWM_CMP0, 0xFFFF
    PW PWM_CFG, 0
    PW PWM_COUNT, 0
    PW PWM_CFG, 0
    CHKIP 0                         // nothing pending in the PWM
    DELAY 8
    csrr t2, mip
    srli t2, t2, 11
    andi t2, t2, 1
    CHKR t2, 1                      // but the PLIC holds both pulses
    jal ra, pwm_plic_claim
    CHKR a0, 11
    jal ra, pwm_plic_claim
    CHKR a0, 13
    jal ra, pwm_plic_claim
    CHKR a0, 0
    QUIESCE

    j terminate_test

PWM_HELPERS

INIT_TEST_TABLE

TEST_STACK_AND_DATA

.align REGSHIFT
test_cases:
    WORD 0x0, 0x0, terminate_test

EXPECT 0x0000000B                   // ecall from test termination in M mode
EXPECT_END
