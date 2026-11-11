///////////////////////////////////////////
// WALLY-pwm-center-01.S
//
// Purpose: Centered PWM sticky/deglitch regression, following FU540-C000 v1.0 sections 14.8,
//          14.10 and 14.13. Exercise all four channels, including software acknowledgement and
//          threshold changes in each half-cycle. The stopped counter makes the checks independent
//          of instruction timing; the existing stress tests also exercise running cycle boundaries.
//
// Copyright (C) 2026 Harvey Mudd College & Oklahoma State University
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
    QUIESCE

.macro CMP_ALL value
    PW PWM_CMP0, \value
    PW PWM_CMP1, \value
    PW PWM_CMP2, \value
    PW PWM_CMP3, \value
.endm

    // Sticky must retain interrupts in the descending half, with or without deglitch.
    .irp mode, 0, CFG_DEGLITCH
    CMP_ALL 0x1000
    PW PWM_CFG, 0xF0000 | CFG_STICKY | \mode
    PW PWM_COUNT, 0x2000
    CHKIP 15
    PW PWM_COUNT, 0xF000             // centered count = 0x0FFF, below every threshold
    CHKIP 15
    CHKPINS 15
    PW PWM_COUNT, 0                 // sticky survives into the ascending half as well
    CHKIP 15
    PW PWM_COUNT, 0xF000
    PW PWM_CFG, 0xF0000 | CFG_STICKY | \mode // software can acknowledge while sticky is set
    CHKIP 0
    CHKPINS 0
    PW PWM_COUNT, 0x2000            // a new comparator event can set IP again
    CHKIP 15
    QUIESCE
    .endr

    // With deglitch, threshold updates cannot create a second edge in either half-cycle.
    PW PWM_CFG, 0xF0000 | CFG_DEGLITCH
    PW PWM_COUNT, 0x2000
    CMP_ALL 0x1000
    CHKIP 15
    CMP_ALL 0x3000                  // no falling edge in the ascending half
    CHKIP 15
    PW PWM_COUNT, 0x8100            // descending centered count = 0x7EFF
    CHKIP 15
    CMP_ALL 0x7F00                  // first falling edge is allowed
    CHKIP 0
    CMP_ALL 0x1000                  // must not rise again in the descending half
    CHKIP 0
    CHKPINS 0
    PW PWM_COUNT, 0                 // next ascending half can generate a new pulse
    CHKIP 0
    PW PWM_COUNT, 0x2000
    CHKIP 15
    QUIESCE

    // Without deglitch, descending comparator changes must still propagate both ways.
    PW PWM_CFG, 0xF0000
    PW PWM_COUNT, 0x8100
    CMP_ALL 0x1000
    CHKIP 15
    CMP_ALL 0x7F00
    CHKIP 0
    CMP_ALL 0x1000
    CHKIP 15
    QUIESCE

    j terminate_test

PWM_HELPERS
INIT_TEST_TABLE
TEST_STACK_AND_DATA

.align REGSHIFT
test_cases:
    WORD 0x0, 0x0, terminate_test

EXPECT 0x0000000B
EXPECT_END
