///////////////////////////////////////////
// WALLY-pwm-stress-01.S
//
// Purpose: PWM register-level stress test: field widths and readback of every register, pwms field
//          selection for every pwmscale, reserved offsets, sub-word and doubleword accesses, the
//          exact comparator boundary (pwms >= pwmcmpX) for every comparator and several scales,
//          center mode on every comparator, the gang output stage for every pending/gang pattern, and
//          the per-comparator PLIC sources.  The counter is stopped throughout, so every check is a
//          static readback.  Expected values follow the SiFive FE310-G002 Manual v1p4, chapter 20.
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
    QUIESCE

// ===================================================================================================
// 1. pwmcfg fields (Table 89).  Writable fields: scale[3:0], sticky 8, zerocmp 9, deglitch 10,
//    enalways 12, enoneshot 13, center[19:16], gang[27:24], ip[31:28].  Reserved bits read zero.
// ===================================================================================================
    // The sticky/deglitch hold is registered (Figure 11: the OR of pwmsticky and pwmdeglitch feeds a
    // flop before gating the pending bits), so pwmsticky must already be set when pending bits are
    // written for them to be held.
    PW PWM_CFG, CFG_STICKY
    PW PWM_CFG, 0xFFFFCFFF          // every bit except the two enables
    CHK PWM_CFG, 0xFF0F070F         // ip held by pwmsticky
    PW PWM_CFG, 0x00F0C8F0          // only reserved bits
    CHK PWM_CFG, 0x00000000

    // One bit at a time.  The pending bits are written without pwmsticky or pwmdeglitch, so they are
    // recomputed from the (low) comparators on the next cycle and read back as zero (20.1, 20.8).
    .irp bit, 0,1,2,3,4,5,6,7,8,9,10,11,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
    PW PWM_CFG, (1 << \bit)
    CHK PWM_CFG, ((1 << \bit) & 0x0F0F070F)
    .endr

    // The pending bits read back while pwmsticky holds them (20.8)
    PW PWM_CFG, CFG_STICKY
    .irp ip, 1,2,4,8,15
    PW PWM_CFG, ((\ip << 28) | CFG_STICKY)
    CHK PWM_CFG, ((\ip << 28) | CFG_STICKY)
    .endr
    // and also while pwmdeglitch holds them, the counter being stopped so no cycle ends
    PW PWM_CFG, CFG_DEGLITCH
    PW PWM_CFG, (0xA << 28) | CFG_DEGLITCH
    CHK PWM_CFG, (0xA << 28) | CFG_DEGLITCH
    // A pwmcfg write replaces the pending bits: writing zeros clears them even with pwmsticky (20.13)
    PW PWM_CFG, CFG_STICKY | CFG_DEGLITCH
    CHK PWM_CFG, CFG_STICKY | CFG_DEGLITCH
    // lw sign extends bit 31 on RV64
    PW PWM_CFG, (8 << 28) | CFG_STICKY
    lw t2, PWM_CFG(s0)
    CHKR t2, SEXT32(0x80000100)

    // pwmenalways reads back; the counter runs
    PW PWM_CFG, CFG_ALWAYS
    CHK PWM_CFG, CFG_ALWAYS
    // pwmenoneshot reads back while the one-shot cycle (65536 counts, no pwmzerocmp) is running
    PW PWM_CFG, CFG_ONESHOT
    CHK PWM_CFG, CFG_ONESHOT
    QUIESCE

// ===================================================================================================
// 2. pwmcount (20.4, Table 88): 31 bits, bit 31 reads zero.
// ===================================================================================================
    PW PWM_COUNT, 0xFFFFFFFF
    CHK PWM_COUNT, 0x7FFFFFFF
    PW PWM_COUNT, 0x80000000
    CHK PWM_COUNT, 0x00000000
    PW PWM_COUNT, 0xAAAAAAAA
    CHK PWM_COUNT, 0x2AAAAAAA
    PW PWM_COUNT, 0x55555555
    CHK PWM_COUNT, 0x55555555

    // pwms is the 16-bit field of pwmcount starting at bit pwmscale, for every pwmscale (20.5, 20.6)
    PW PWM_COUNT, 0x5A5AC3C3
    .irp s, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    PW PWM_CFG, \s
    CHK PWM_S, ((0x5A5AC3C3 >> \s) & 0xFFFF)
    .endr
    PW PWM_COUNT, 0x7FFFFFFF
    CHK PWM_S, 0xFFFF               // pwmscale is still 15: pwms = pwmcount[30:15]
    PW PWM_COUNT, 0x00007FFF
    CHK PWM_S, 0x0000

    // pwms is RW (Table 90): it reads back what was written, through the pwmcount field it reports,
    // for every pwmscale.  The bits above cmpwidth are reserved and are dropped.
    .irp s, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    PW PWM_CFG, \s
    PW PWM_S, 0xFFFFA5C3
    CHK PWM_S, 0xA5C3
    CHKM PWM_COUNT, (0xFFFF << \s), (0xA5C3 << \s)
    .endr
    QUIESCE

// ===================================================================================================
// 3. pwmcmp0-3 (20.7): 16 bits, reserved upper bits read zero; each register is independent.
// ===================================================================================================
    .irp off, PWM_CMP0, PWM_CMP1, PWM_CMP2, PWM_CMP3
    PW \off, 0xFFFFFFFF
    CHK \off, 0xFFFF
    PW \off, 0x00010000
    CHK \off, 0x0000
    .endr
    PW PWM_CMP0, 0x1111
    PW PWM_CMP1, 0x2222
    PW PWM_CMP2, 0x3333
    PW PWM_CMP3, 0x4444
    CHK PWM_CMP0, 0x1111
    CHK PWM_CMP1, 0x2222
    CHK PWM_CMP2, 0x3333
    CHK PWM_CMP3, 0x4444

// ===================================================================================================
// 4. Reserved offsets (Table 87) read zero, and writes to them change no register.
// ===================================================================================================
    PW PWM_CFG, 0x0F0F0703          // known values everywhere (counter stopped)
    PW PWM_COUNT, 0x70000007        // pwms = 0 at pwmscale 3: every comparator low
    .irp off, 0x04, 0x0C, 0x14, 0x18, 0x1C, 0x30, 0x34, 0x38, 0x3C, 0x40, 0x80, 0xFC
    PW \off, 0xFFFFFFFF
    CHK \off, 0x00000000
    .endr
    CHK PWM_CFG, 0x0F0F0703
    CHK PWM_COUNT, 0x70000007
    CHK PWM_CMP0, 0x1111
    CHK PWM_CMP1, 0x2222
    CHK PWM_CMP2, 0x3333
    CHK PWM_CMP3, 0x4444
    QUIESCE

// ===================================================================================================
// 5. Access size.  Wally's PMA makes the PWM region word-only (src/mmu/adrdecs.sv): byte, halfword,
//    and doubleword accesses take an access fault and must not modify the register.  (The FE310
//    manual does not define sub-word accesses; this checks the documented Wally behavior.)
// ===================================================================================================
    PW PWM_CMP2, 0x1234
    PW PWM_CFG, 0x00000305
    li t2, 0xFF
    sb t2, PWM_CFG(s0)
    EXPECT_TRAP 7
    sb t2, PWM_CFG+3(s0)
    EXPECT_TRAP 7
    sh t2, PWM_CFG+2(s0)
    EXPECT_TRAP 7
    sh t2, PWM_CMP2(s0)
    EXPECT_TRAP 7
    sb t2, PWM_CMP2+1(s0)
    EXPECT_TRAP 7
    lb t2, PWM_CFG(s0)
    EXPECT_TRAP 5
    lbu t2, PWM_CFG+1(s0)
    EXPECT_TRAP 5
    lh t2, PWM_CMP2(s0)
    EXPECT_TRAP 5
    lhu t2, PWM_CMP2+2(s0)
    EXPECT_TRAP 5
#if __riscv_xlen == 64
    li t2, -1
    sd t2, PWM_CMP2(s0)
    EXPECT_TRAP 7
    ld t2, PWM_CMP2(s0)
    EXPECT_TRAP 5
    ld t2, PWM_CFG(s0)
    EXPECT_TRAP 5
#endif
    CHK PWM_CFG, 0x00000305         // unchanged by the faulting stores
    CHK PWM_CMP2, 0x1234
    CHK PWM_CMP3, 0xFFFF
    QUIESCE

// ===================================================================================================
// 6. Comparator boundary (20.7): "The output of each comparator is high whenever the value of pwms
//    is greater than or equal to the corresponding pwmcmp."  The counter is stopped, so pwmcmpXip
//    follows the comparator (one cycle later).  pwms = 0x1234 at pwmscale 0, 7, and 15, with the
//    bits below pwms all ones and (below scale 15) bit 30 set above pwms, which must not matter.
// ===================================================================================================
.macro CMP_BOUNDARY s, x
    PW PWM_CFG, \s
.if \s < 15
    PW PWM_COUNT, ((1 << 30) | (0x1234 << \s) | ((1 << \s) - 1))
.else
    PW PWM_COUNT, ((0x1234 << \s) | ((1 << \s) - 1))
.endif
    PW (PWM_CMP0 + 4*\x), 0x1233
    CHKIP (1 << \x)
    PW (PWM_CMP0 + 4*\x), 0x1234
    CHKIP (1 << \x)
    PW (PWM_CMP0 + 4*\x), 0x1235
    CHKIP 0
.endm
    .irp s, 0, 7, 15
    .irp x, 0, 1, 2, 3
    CMP_BOUNDARY \s, \x
    .endr
    .endr

    // pwmcmp = 0 is always high (pwms >= 0); pwmcmp = 0xFFFF only when pwms is all ones
    QUIESCE
    .irp x, 0, 1, 2, 3
    PW PWM_COUNT, 0
    PW (PWM_CMP0 + 4*\x), 0x0000
    CHKIP (1 << \x)
    PW (PWM_CMP0 + 4*\x), 0xFFFF
    CHKIP 0
    PW PWM_COUNT, 0xFFFE
    CHKIP 0
    .endr
    PW PWM_COUNT, 0xFFFF            // all four at 0xFFFF fire together
    CHKIP 0xF
    PW PWM_COUNT, 0x0001FFFF        // bit 16 is above pwms at scale 0
    CHKIP 0xF
    QUIESCE

// ===================================================================================================
// 7. Center mode (20.10, Table 95): the comparator sees ~pwms whenever pwms[15] is set.  Every
//    comparator, pwmscale 0.  Only the centered comparator's own pending bit is checked.
// ===================================================================================================
.macro CENTER_CASE x, s, count, cmp, exp
    PW PWM_COUNT, \count
    PW (PWM_CMP0 + 4*\x), \cmp
    CHKM PWM_CFG, (CFG_IP0 << \x), (\exp << (28 + \x))
.endm
    .irp x, 0, 1, 2, 3
    PW PWM_CFG, (CFG_CENTER0 << \x)
    CENTER_CASE \x, 0, 0x0000, 0x0000, 1
    CENTER_CASE \x, 0, 0x0000, 0x0001, 0
    CENTER_CASE \x, 0, 0x4000, 0x4000, 1
    CENTER_CASE \x, 0, 0x7FFF, 0x7FFF, 1
    CENTER_CASE \x, 0, 0x7FFF, 0x8000, 0
    CENTER_CASE \x, 0, 0x8000, 0x7FFF, 1     // pwmscenter = 0x7FFF
    CENTER_CASE \x, 0, 0x8000, 0x8000, 0
    CENTER_CASE \x, 0, 0xC000, 0x3FFF, 1     // pwmscenter = 0x3FFF
    CENTER_CASE \x, 0, 0xC000, 0x4000, 0
    CENTER_CASE \x, 0, 0xFFFF, 0x0000, 1     // pwmscenter = 0
    CENTER_CASE \x, 0, 0xFFFF, 0x0001, 0
    PW (PWM_CMP0 + 4*\x), 0xFFFF
    .endr
    // The center bit only affects its own comparator: at pwms = 0xFFFF the centered comparator 0
    // (pwmcmp0 = 1) is low, while comparators 1 (pwmcmp1 = 1), 2 and 3 (0xFFFF) are high
    PW PWM_CFG, CFG_CENTER0
    PW PWM_COUNT, 0xFFFF
    PW PWM_CMP0, 0x0001
    PW PWM_CMP1, 0x0001
    CHKIP 0xE
    // The MSB is pwms[15], not pwmcount[15]: at pwmscale 9, pwmcount = 0x01000000 has pwms = 0x8000
    PW PWM_CFG, (CFG_CENTER0 << 3) | 9
    PW PWM_COUNT, 0x01000000
    PW PWM_CMP3, 0x7FFF
    CHKM PWM_CFG, (CFG_IP0 << 3), (CFG_IP0 << 3)
    PW PWM_CMP3, 0x8000
    CHKM PWM_CFG, (CFG_IP0 << 3), 0
    PW PWM_COUNT, 0x00008000        // pwmcount[15] set, pwms = 0x0040
    PW PWM_CMP3, 0x0040
    CHKM PWM_CFG, (CFG_IP0 << 3), (CFG_IP0 << 3)
    PW PWM_CMP3, 0x0041
    CHKM PWM_CFG, (CFG_IP0 << 3), 0
    QUIESCE

// ===================================================================================================
// 8. Gang output stage (20.11, Figure 11): pwmXgpio = pwmcmpXip & ~(pwmcmpXgang & pwmcmp(X+1)ip),
//    with comparator 3 ganged to comparator 0.  The pending bits are written through pwmcfg and held
//    by pwmsticky (comparators low).  For each gang pattern, the pins seen for pending patterns 0-7
//    and 8-15 are packed into one nibble each.
// ===================================================================================================
.macro GANG_HALF g, base
    li a2, 0
    .set gexp, 0
    .irp i, 0,1,2,3,4,5,6,7
    .set ipv, (\base + \i)
    PW PWM_CFG, ((ipv << 28) | (\g << 24) | CFG_STICKY)
    li a0, 12
    jal ra, pwm_delay
    lw t2, GPIO_INPUT_VAL(s1)
    andi t2, t2, 0xF
    slli a2, a2, 4
    or a2, a2, t2
    .set gexp, ((gexp << 4) | ((ipv & ~(\g & ((ipv >> 1) | ((ipv & 1) << 3)))) & 0xF))
    .endr
    CHKR a2, gexp
.endm
    .irp g, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    GANG_HALF \g, 0
    GANG_HALF \g, 8
    .endr
    QUIESCE
    CHKPINS 0

// ===================================================================================================
// 9. PLIC sources (20.13): pwmcmpXip is PLIC source 11+X.  Pending bits in the PLIC follow each
//    comparator individually; the machine-mode enable masks each one.
// ===================================================================================================
    jal ra, pwm_plic_setup
    jal ra, pwm_plic_drain
    li s2, PLIC_PENDING0
    .irp ip, 1, 2, 4, 8, 5, 10, 15
    PW PWM_CFG, (\ip << 28) | CFG_STICKY
    DELAY 8
    lw t2, 0(s2)
    srli t2, t2, PWM_IRQ0
    andi t2, t2, 0xF
    CHKR t2, \ip                    // exactly the pending comparators are pending in the PLIC
    PW PWM_CFG, CFG_STICKY          // clear the pending bits, then drain the PLIC
    jal ra, pwm_plic_drain
    .endr
    // Masking: disable source 13 in the machine-mode enables; pwmcmp2ip set gives no MEIP
    li s3, PLIC_EN0
    li t2, (0xB << PWM_IRQ0)
    sw t2, 0(s3)
    PW PWM_CFG, (4 << 28) | CFG_STICKY
    DELAY 8
    csrr t2, mip
    srli t2, t2, 11
    andi t2, t2, 1
    CHKR t2, 0                      // masked: no machine external interrupt
    lw t2, 0(s2)
    srli t2, t2, PWM_IRQ0
    andi t2, t2, 0xF
    CHKR t2, 4                      // but the source is pending
    li t2, (0xF << PWM_IRQ0)
    sw t2, 0(s3)                    // enable it
    DELAY 8
    csrr t2, mip
    srli t2, t2, 11
    andi t2, t2, 1
    CHKR t2, 1
    PW PWM_CFG, CFG_STICKY
    jal ra, pwm_plic_claim
    CHKR a0, 13
    jal ra, pwm_plic_claim
    CHKR a0, 0                      // nothing else pending
    DELAY 8
    csrr t2, mip
    srli t2, t2, 11
    andi t2, t2, 1
    CHKR t2, 0
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
