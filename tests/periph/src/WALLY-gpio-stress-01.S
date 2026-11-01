///////////////////////////////////////////
// WALLY-gpio-stress-01.S
//
// Purpose: GPIO register file: reset values, writable bits of every register (all-ones, all-zeros,
//          checkerboards, walking ones and zeros), independence of the registers, the read-only
//          input_val, write-1-to-clear-only pending bits, unmapped offsets, and the access sizes the
//          GPIO accepts.  No pin is enabled as an input except where stated, so the pins read 0.
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

// mcause of a misaligned word access to the GPIO.  The privileged spec allows an address-misaligned or an
// access fault.  rv64gc (ZICCLSM_SUPPORTED = 1) splits the access in hardware and the word-only PMA then
// faults it; rv32gc (ZICCLSM_SUPPORTED = 0) reports address-misaligned.  The periph tests run on these two.
#if __riscv_xlen == 64
.equ MISALIGNED_LOAD,  5
.equ MISALIGNED_STORE, 7
#else
.equ MISALIGNED_LOAD,  4
.equ MISALIGNED_STORE, 6
#endif

// Write all-ones, all-zeros, both checkerboards, walking ones and walking zeros to register \off and
// check each reads back (17.2: each register is ngpio = 32 bits wide), then leave it 0.
.macro RW_SWEEP off
    GW \off, 0xFFFFFFFF
    CHK \off, 0xFFFFFFFF
    GW \off, 0x00000000
    CHK \off, 0x00000000
    GW \off, 0xA5A5A5A5
    CHK \off, 0xA5A5A5A5
    GW \off, 0x5A5A5A5A
    CHK \off, 0x5A5A5A5A
    li a0, \off
    li a2, 0
    jal ra, walk                // walking ones: a0 = mask of bits that read back
    SIGRX a0, 0xFFFFFFFF
    li a0, \off
    li a2, -1
    jal ra, walk                // walking zeros
    SIGRX a0, 0xFFFFFFFF
    GW \off, 0
    CHK \off, 0
.endm

// Check every register offset 0x00-0x48 against the given values.
.macro CHK_ALL iv, ie, oe, ov, rie, rip, fie, fip, hie, hip, lie, lip, ioe, ios, ox
    CHK GPIO_INPUT_VAL,   \iv
    CHK GPIO_INPUT_EN,    \ie
    CHK GPIO_OUTPUT_EN,   \oe
    CHK GPIO_OUTPUT_VAL,  \ov
    CHK GPIO_PUE,         0
    CHK GPIO_DS,          0
    CHK GPIO_RISE_IE,     \rie
    CHK GPIO_RISE_IP,     \rip
    CHK GPIO_FALL_IE,     \fie
    CHK GPIO_FALL_IP,     \fip
    CHK GPIO_HIGH_IE,     \hie
    CHK GPIO_HIGH_IP,     \hip
    CHK GPIO_LOW_IE,      \lie
    CHK GPIO_LOW_IP,      \lip
    CHK GPIO_IOF_EN,      \ioe
    CHK GPIO_IOF_SEL,     \ios
    CHK GPIO_OUT_XOR,     \ox
    CHK GPIO_PASSTHRU_HI, 0
    CHK GPIO_PASSTHRU_LO, 0
.endm

INIT_TESTS

TRAP_HANDLER m

GPIO_TEST_BEGIN

// ---------------- Reset values (Table 52: all registers reset to 0) ----------------
// pue and ds are not implemented by Wally (gpio_apb.sv header) and read 0.  passthru_*_ie exist only in
// the v1p4 manual.  With input_en = 0 every pin reads 0 (17.3), so low_ip is set on every pin as soon
// as reset ends (17.4: level interrupt on a low pin) and nothing else is pending.
    CHK_ALL 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFFFFFFFF, 0, 0, 0

// ---------------- Writable bits: every bit of every read/write register ----------------
// input_en is swept while output_en = 0 (the pins read GPIOIN = 0), so no pending bit changes.
    RW_SWEEP GPIO_INPUT_EN
    RW_SWEEP GPIO_OUTPUT_EN
    RW_SWEEP GPIO_OUTPUT_VAL
    RW_SWEEP GPIO_RISE_IE
    RW_SWEEP GPIO_FALL_IE
    RW_SWEEP GPIO_HIGH_IE
    RW_SWEEP GPIO_LOW_IE
    RW_SWEEP GPIO_IOF_EN
    RW_SWEEP GPIO_IOF_SEL
    RW_SWEEP GPIO_OUT_XOR
// The low_ie sweep met low_ip = all ones and so raised the GPIO interrupt, but the PLIC has not been set
// up (source priority 0 never exceeds the threshold), so MEIP stays 0.
    CHK_MEIP 0

// pue and ds: Wally implements neither (documented deviation), so writes are ignored.
    GW GPIO_PUE, 0xFFFFFFFF
    CHK GPIO_PUE, 0
    GW GPIO_DS, 0xFFFFFFFF
    CHK GPIO_DS, 0

// ---------------- Register independence: distinct values in every register ----------------
// Round A: input_en holds a pattern with output_en = 0, so the pins still read 0 (GPIOIN = 0).
    GW GPIO_INPUT_EN,   0x01234567
    GW GPIO_OUTPUT_EN,  0x00000000
    GW GPIO_OUTPUT_VAL, 0x89ABCDEF
    GW GPIO_RISE_IE,    0x11111111
    GW GPIO_FALL_IE,    0x22222222
    GW GPIO_HIGH_IE,    0x44444444
    GW GPIO_LOW_IE,     0x88888888
    GW GPIO_IOF_EN,     0x0F0F0F0F
    GW GPIO_IOF_SEL,    0xF0F0F0F0
    GW GPIO_OUT_XOR,    0x3C3C3C3C
    SETTLE
    CHK_ALL 0, 0x01234567, 0, 0x89ABCDEF, 0x11111111, 0, 0x22222222, 0, 0x44444444, 0, 0x88888888, 0xFFFFFFFF, 0x0F0F0F0F, 0xF0F0F0F0, 0x3C3C3C3C
// Round B: complementary values, input_en = 0 so output_en may hold a pattern without any pin changing.
    GW GPIO_INPUT_EN,   0x00000000
    GW GPIO_OUTPUT_EN,  0xFEDCBA98
    GW GPIO_OUTPUT_VAL, 0x76543210
    GW GPIO_RISE_IE,    0xEEEEEEEE
    GW GPIO_FALL_IE,    0xDDDDDDDD
    GW GPIO_HIGH_IE,    0xBBBBBBBB
    GW GPIO_LOW_IE,     0x77777777
    GW GPIO_IOF_EN,     0xF0F0F0F0
    GW GPIO_IOF_SEL,    0x0F0F0F0F
    GW GPIO_OUT_XOR,    0xC3C3C3C3
    SETTLE
    CHK_ALL 0, 0, 0xFEDCBA98, 0x76543210, 0xEEEEEEEE, 0, 0xDDDDDDDD, 0, 0xBBBBBBBB, 0, 0x77777777, 0xFFFFFFFF, 0xF0F0F0F0, 0x0F0F0F0F, 0xC3C3C3C3
// Back to reset state.
    GW GPIO_OUTPUT_EN, 0
    GW GPIO_OUTPUT_VAL, 0
    GW GPIO_RISE_IE, 0
    GW GPIO_FALL_IE, 0
    GW GPIO_HIGH_IE, 0
    GW GPIO_LOW_IE, 0
    GW GPIO_IOF_EN, 0
    GW GPIO_IOF_SEL, 0
    GW GPIO_OUT_XOR, 0

// ---------------- input_val is read-only (17.3: it returns the pin value) ----------------
    GW GPIO_INPUT_VAL, 0xFFFFFFFF
    CHK GPIO_INPUT_VAL, 0
    // drive 0x0F0F0F0F on the pins through the loopback and read it while writing input_val
    GW GPIO_OUTPUT_VAL, 0x0F0F0F0F
    GW GPIO_OUTPUT_EN, 0xFFFFFFFF
    GW GPIO_INPUT_EN, 0xFFFFFFFF
    SETTLE
    CHK GPIO_INPUT_VAL, 0x0F0F0F0F
    GW GPIO_INPUT_VAL, 0xF0F0F0F0
    SETTLE
    CHK GPIO_INPUT_VAL, 0x0F0F0F0F
    GW GPIO_INPUT_VAL, 0x00000000
    SETTLE
    CHK GPIO_INPUT_VAL, 0x0F0F0F0F
    GW GPIO_INPUT_EN, 0
    GW GPIO_OUTPUT_EN, 0
    GW GPIO_OUTPUT_VAL, 0
    SETTLE

// ---------------- Pending bits cannot be set by software (17.4: writing 1 clears) ----------------
// Pins read 0 (input_en = 0), so only low_ip has a condition.  The input_en/output_en changes just above
// left rise/fall/high pending bits; clear them first.
    CLEAR_IP
    SETTLE
    CHK GPIO_RISE_IP, 0
    CHK GPIO_FALL_IP, 0
    CHK GPIO_HIGH_IP, 0
    CHK GPIO_LOW_IP, 0xFFFFFFFF     // set again at once: the pins are still low
    GW GPIO_RISE_IP, 0xFFFFFFFF
    GW GPIO_FALL_IP, 0xFFFFFFFF
    GW GPIO_HIGH_IP, 0xFFFFFFFF
    CHK GPIO_RISE_IP, 0
    CHK GPIO_FALL_IP, 0
    CHK GPIO_HIGH_IP, 0
    // and writing the ip registers changes no other register
    CHK_ALL 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFFFFFFFF, 0, 0, 0

// ---------------- Unmapped offsets read 0 and ignore writes ----------------
// Wally decodes the 256-byte GPIO region (GPIO_RANGE = 0xFF); offsets past out_xor are unmapped.
    GW 0x44, 0xFFFFFFFF
    CHK 0x44, 0
    GW 0x48, 0xFFFFFFFF
    CHK 0x48, 0
    GW 0x4C, 0xFFFFFFFF
    CHK 0x4C, 0
    GW 0x50, 0xFFFFFFFF
    CHK 0x50, 0
    GW 0x7C, 0xFFFFFFFF
    CHK 0x7C, 0
    GW 0x80, 0xFFFFFFFF
    CHK 0x80, 0
    GW 0x84, 0xFFFFFFFF
    CHK 0x84, 0
    GW 0x8C, 0xFFFFFFFF
    CHK 0x8C, 0
    GW 0xC0, 0xFFFFFFFF
    CHK 0xC0, 0
    GW 0xF8, 0xFFFFFFFF
    CHK 0xF8, 0
    GW 0xFC, 0xFFFFFFFF
    CHK 0xFC, 0
    // none of those writes aliased onto a real register
    CHK_ALL 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFFFFFFFF, 0, 0, 0

// ---------------- Access sizes ----------------
// Table 52: "Only naturally aligned 32-bit memory accesses are supported."  What other accesses do is
// not specified; Wally's PMA (adrdecs.sv) makes the GPIO word-only, so they take an access fault
// (load 5, store 7), the load leaves rd unchanged, and the store leaves the register unchanged.
    GW GPIO_OUTPUT_VAL, 0x12345678
    .irp off, 0, 1, 2, 3
    li t4, 0xBAD
    EXPECT_TRAP 5, lb t4, (GPIO_OUTPUT_VAL+\off)(s0)
    SIGRX t4, 0xBAD
    li t4, 0xBAD
    EXPECT_TRAP 5, lbu t4, (GPIO_OUTPUT_VAL+\off)(s0)
    SIGRX t4, 0xBAD
    li t4, 0xFF
    EXPECT_TRAP 7, sb t4, (GPIO_OUTPUT_VAL+\off)(s0)
    .endr
    .irp off, 0, 2
    li t4, 0xBAD
    EXPECT_TRAP 5, lh t4, (GPIO_OUTPUT_VAL+\off)(s0)
    SIGRX t4, 0xBAD
    li t4, 0xBAD
    EXPECT_TRAP 5, lhu t4, (GPIO_OUTPUT_VAL+\off)(s0)
    SIGRX t4, 0xBAD
    li t4, 0xFFFF
    EXPECT_TRAP 7, sh t4, (GPIO_OUTPUT_VAL+\off)(s0)
    .endr
    CHK GPIO_OUTPUT_VAL, 0x12345678
    // misaligned words: also not naturally aligned; the privileged spec allows an address-misaligned or
    // an access fault (MISALIGNED_LOAD/STORE above).
    .irp off, 1, 2, 3
    li t4, 0xBAD
    EXPECT_TRAP MISALIGNED_LOAD, lw t4, (GPIO_OUTPUT_VAL+\off)(s0)
    SIGRX t4, 0xBAD
    li t4, -1
    EXPECT_TRAP MISALIGNED_STORE, sw t4, (GPIO_OUTPUT_VAL+\off)(s0)
    .endr
    CHK GPIO_OUTPUT_VAL, 0x12345678
    CHK GPIO_IOF_EN, 0              // the next register up was not written either
    CHK GPIO_OUTPUT_EN, 0           // nor the one below
#if __riscv_xlen == 64
    // 64-bit accesses: not supported (word-only PMA)
    li t4, 0xBAD
    EXPECT_TRAP 5, ld t4, GPIO_OUTPUT_EN(s0)
    SIGRX t4, 0xBAD
    li t4, -1
    EXPECT_TRAP 7, sd t4, GPIO_OUTPUT_EN(s0)
    CHK GPIO_OUTPUT_EN, 0
    CHK GPIO_OUTPUT_VAL, 0x12345678
    // lwu reads the same word, zero extended
    GW GPIO_OUTPUT_VAL, 0xA5A5A5A5
    lwu t4, GPIO_OUTPUT_VAL(s0)
    srli t4, t4, 32
    SIGRX t4, 0                     // upper word of the zero-extended value
    lwu t4, GPIO_OUTPUT_VAL(s0)
    SIGRX t4, 0xA5A5A5A5
    // an aligned word in the upper half of a doubleword (offsets 0x04, 0x0C, ...) selects its own register
    GW GPIO_OUTPUT_EN, 0x0000FFFF
    CHK GPIO_OUTPUT_EN, 0x0000FFFF
    CHK GPIO_OUTPUT_VAL, 0xA5A5A5A5
    GW GPIO_OUTPUT_EN, 0
#else
    // keep the entry count equal on RV32
    GW GPIO_OUTPUT_VAL, 0xA5A5A5A5
    EXP 5
    EXP 0xBAD
    EXP 7
    EXP 0
    EXP 0x12345678
    EXP 0
    EXP 0xA5A5A5A5
    EXP 0x0000FFFF
    EXP 0xA5A5A5A5
    j 1f
1:
    li t2, 5
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 0xBAD
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 7
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 0
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 0x12345678
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 0
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 0xA5A5A5A5
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 0x0000FFFF
    SREG t2, 0(t1)
    SIG_NEXT
    li t2, 0xA5A5A5A5
    SREG t2, 0(t1)
    SIG_NEXT
#endif

// Atomic memory operations: 17 notes "Atomic operations such as toggles are natively possible with the
// RISC-V 'A' extension" on the FE310.  Wally allows AMOs only on RAM (pmachecker.sv AtomicAllowed), a
// documented design choice, so they take a store/AMO access fault and leave the register unchanged.
    GW GPIO_OUTPUT_VAL, 0x0000FF00
    .option push
    .option arch, +a
    addi t5, s0, GPIO_OUTPUT_VAL
    li t4, 0x000000FF
    EXPECT_TRAP 7, amoxor.w t3, t4, (t5)
    EXPECT_TRAP 7, amoor.w t3, t4, (t5)
    EXPECT_TRAP 7, amoswap.w t3, t4, (t5)
    EXPECT_TRAP 5, lr.w t3, (t5)
    EXPECT_TRAP 7, sc.w t3, t4, (t5)
    .option pop
    CHK GPIO_OUTPUT_VAL, 0x0000FF00
    GW GPIO_OUTPUT_VAL, 0

// Past the end of the GPIO region (GPIO_BASE + GPIO_RANGE + 1) nothing is mapped: access fault.
    li t5, GPIO+0x100
    li t4, 0xBAD
    EXPECT_TRAP 5, lw t4, 0(t5)
    SIGRX t4, 0xBAD

// Everything is back at its reset value.
    CHK_ALL 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFFFFFFFF, 0, 0, 0

GPIO_TEST_END

// walk: write a pattern with one bit different from the rest (a2 = 0: walking one, a2 = -1: walking zero)
// to GPIO register s0 + a0 for each of the 32 bits and read it back.  Returns a0 = mask of the bit
// positions whose pattern read back unchanged.  Uses a1, a3, t3-t6.
walk:
    add t4, s0, a0
    li a1, 0                // mask
    li t5, 1                // 1 << i
    li a3, 32
1:
    xor t6, t5, a2          // pattern
#if __riscv_xlen == 64
    addiw t6, t6, 0         // as lw returns it
#endif
    sw t6, 0(t4)
    lw t3, 0(t4)
    bne t3, t6, 2f
    or a1, a1, t5
2:
    slli t5, t5, 1
    addi a3, a3, -1
    bnez a3, 1b
    mv a0, a1
    ret

GPIO_HELPERS

TEST_STACK_AND_DATA
