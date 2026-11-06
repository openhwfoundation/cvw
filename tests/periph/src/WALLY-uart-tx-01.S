///////////////////////////////////////////
// WALLY-uart-tx-01.S
//
// Purpose: UART transmitter and character format: data lengths, parity (odd, even, stick), stop
//          bits, framing errors and breaks, baud divisor timing, THRE/TEMT sequencing, the 16-byte
//          transmit FIFO, and transmit FIFO reset (FCR[2]) and FIFO enable changes while characters
//          are queued or in flight.  Expected values follow the PC16550D datasheet (see WALLY-uart.h).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"
#include "WALLY-uart.h"

INIT_TESTS

TRAP_HANDLER m

    li s0, UART
    jal ra, uart_quiesce            // loopback, FIFOs off
    li a0, 2
    jal ra, uart_set_divisor
    jal ra, uart_calibrate

// ---------------- Character formats (8.1, 8.4) ----------------
// Each row of xfer_table is (data, LCR while transmitting, LCR while receiving).  Changing LCR after
// the character has started makes the receiver check it against a different format.  Parity rows
// check the transmitted parity bit (including stick parity, LCR[5]).  Framing rows swap one data or
// parity bit for a second stop bit (e.g. 8N1 sent, 7N2 received), so the transmitted frame has the
// same length while the receiver, which checks only the first stop bit, finds a data or parity bit
// there: a framing error when that bit is 0.  Each row gives three entries:
//   LSR[4:0] when data ready is seen, RBR, and any extra character: 0x100 | RBR, or 0 if none.
// After a framing error the receiver resynchronizes by taking the bad stop bit as the next start
// bit (8.4, FE), so it receives one more character from the marking line that follows: all ones.
// A break (BI) cannot be produced: in loopback the receiver sees the transmit shift register, not
// the break-forced SOUT (8.8, MCR[4]).
    la s2, xfer_table
    la s3, xfer_table_end
xfer_loop:
    lbu a0, 0(s2)
    lbu a1, 1(s2)
    lbu a2, 2(s2)
    jal ra, uart_xfer_switch
    mv s4, a1
    li t2, 0xBAD
    beq a0, t2, 1f
    andi a0, a0, 0x1F
1:
    SIGR a0
    SIGR s4
    jal ra, uart_settle
    andi a0, a0, 0x01
    beqz a0, 2f
    lbu a0, UART_RBR(s0)
    ori a0, a0, 0x100
2:
    SIGR a0
    lbu t2, UART_LSR(s0)            // clear any status of the extra character
    li t2, 0x03
    sb t2, UART_LCR(s0)
    addi s2, s2, 4
    bltu s2, s3, xfer_loop

// ---------------- Format change during a character ----------------
// The datasheet does not say how a character in the shift register is framed if LCR changes while it
// is sent, but the line must return to marking when the transmitter goes idle, so the next character
// is received correctly.  Change 8N1 to 5N1 during an all-zero character, discard whatever is
// received, then send one character: entries LSR[4:0] (0x01), RBR (0x5A), extra character (0).
    li a0, 0x00
    li a1, 0x03
    li a2, 0x00
    jal ra, uart_xfer_switch
    jal ra, uart_settle
    UW UART_LCR, 0x03
    li s2, 4
1:
    lbu t2, UART_RBR(s0)            // discard up to 4 characters
    WAIT_HALF_CHARS 2
    addi s2, s2, -1
    bnez s2, 1b
    lbu t2, UART_LSR(s0)
    li a0, 0x5A
    li a1, 0x03
    li a2, 0x03
    jal ra, uart_xfer_switch
    andi a0, a0, 0x1F
    SIGR a0                         // 0x01
    SIGR a1                         // 0x5A
    jal ra, uart_settle
    andi a0, a0, 0x01
    SIGR a0                         // 0: nothing more

// ---------------- Frame length (8.1: LCR[2] stop bits) ----------------
// Cycles from the THR write until TEMT, relative to an 8N1 character (10 bits), as
// round(20 * T / T(8N1)) = 2 x the number of bit times.  With LCR[2] = 1, 5-bit characters have
// 1.5 stop bits and longer characters have 2. Use a long timing baseline to leave margin for CPU
// polling overhead and baud phase when rounding the frame lengths and divisor ratios.
    jal ra, uart_quiesce
    li a0, 64
    jal ra, uart_set_divisor
    jal ra, uart_calibrate          // s1 = T(8N1)
    la s2, frame_table
    la s3, frame_table_end
frame_loop:
    lbu t2, 0(s2)
    sb t2, UART_LCR(s0)
    li a0, 0x55
    jal ra, uart_frame_cycles
    slli t2, a0, 5
    slli a0, a0, 3
    add a0, a0, t2                  // 40 T
    add a0, a0, s1                  // + T(8N1) to round
    slli a1, s1, 1
    jal ra, uart_div                // (40 T + T0) / (2 T0)
    SIGR a0
    lbu t2, UART_RBR(s0)            // discard the character
    lbu t2, UART_LSR(s0)
    addi s2, s2, 1
    bltu s2, s3, frame_loop
    UW UART_LCR, 0x03

// ---------------- Baud divisor (8.3): character time is proportional to {DLM, DLL} ----------------
// T(d) = character time at divisor d.  U = T(128) - T(64) is 64 divisor units with the fixed polling
// overhead cancelled.
    mv s4, s1                       // T(64)
    li a0, 128
    jal ra, uart_set_divisor
    li a0, 0x55
    jal ra, uart_frame_cycles
    lbu t2, UART_RBR(s0)
    mv s5, a0                       // T(128)
    slli t2, a0, 3
    slli a0, a0, 1
    add a0, a0, t2                  // 10 T(128)
    srli t2, s4, 1
    add a0, a0, t2
    mv a1, s4
    jal ra, uart_div
    SIGR a0                         // round(10 T(128) / T(64)) = 20
    sub s5, s5, s4                  // U
    li a0, 0x1000
    jal ra, uart_set_divisor
    li a0, 0x55
    jal ra, uart_frame_cycles
    lbu t2, UART_RBR(s0)
    sub a0, a0, s4
    srli t2, s5, 1
    add a0, a0, t2
    mv a1, s5
    jal ra, uart_div
    SIGR a0                         // round((T(4096) - T(64)) / U) = 63: DLM is the high byte
    li a0, 0x1020
    jal ra, uart_set_divisor
    li a0, 0x55
    jal ra, uart_frame_cycles
    lbu t2, UART_RBR(s0)
    sub a0, a0, s4
    slli a0, a0, 1
    srli t2, s5, 1
    add a0, a0, t2
    mv a1, s5
    jal ra, uart_div
    SIGR a0                         // round(2 (T(4128) - T(64)) / U) = 127
    li a0, 4
    jal ra, uart_set_divisor

// ---------------- THRE and TEMT, FIFOs off (8.4) ----------------
    jal ra, uart_quiesce
    UW UART_THR, 0x41
    WAIT_LSR 0x60, 0x20             // 0x41 moves to the shift register: THRE, not TEMT
    andi a0, a0, 0x61
    SIGR a0                         // 0x20
    UW UART_THR, 0x42               // waits in THR behind 0x41
    CHKM UART_LSR, 0x61             // 0x00: neither THRE nor TEMT
    WAIT_LSR 0x20, 0x20             // 0x42 moves to the shift register
    andi a0, a0, 0x60
    SIGR a0                         // 0x20
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x41
    WAIT_LSR 0x40, 0x40
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x42
    CHK UART_LSR                    // 0x60

// ---------------- 16-byte transmit FIFO (8.5, 8.11) ----------------
// 17 characters written back to back: one goes to the shift register and 16 wait in the FIFO.
// All 17 must arrive, in order, without overrun (they are read as they arrive).
    jal ra, uart_quiesce
    UW UART_FCR, 0x07
    li s2, 0x30
    li s3, 0x41
1:
    sb s2, UART_THR(s0)
    addi s2, s2, 1
    bltu s2, s3, 1b
    CHKM UART_LSR, 0x60             // 0x00
    li s2, 0x30                     // next character expected
    li s4, 0                        // errors
2:
    WAIT_LSR 0x01, 0x01
    li t2, 0xBAD
    beq a0, t2, 3f
    lbu t2, UART_RBR(s0)
    beq t2, s2, 4f
3:
    addi s4, s4, 1
4:
    addi s2, s2, 1
    bltu s2, s3, 2b
    SIGR s4                         // 0 errors
    jal ra, uart_settle
    SIGR a0                         // 0x60: nothing more, no overrun

// An 18th write while the shift register and all 16 FIFO entries are full has nowhere to go.  The
// datasheet does not say what happens to it, but the 17 characters already accepted must be sent
// unchanged.  Entries: errors among the first 17 characters (0), LSR afterwards (0x60, nothing more).
    jal ra, uart_quiesce
    UW UART_FCR, 0x07
    li s2, 0x30
    li s3, 0x42
1:
    sb s2, UART_THR(s0)
    addi s2, s2, 1
    bltu s2, s3, 1b
    li s2, 0x30
    li s3, 0x41
    li s4, 0
2:
    WAIT_LSR 0x01, 0x01
    li t2, 0xBAD
    beq a0, t2, 3f
    lbu t2, UART_RBR(s0)
    beq t2, s2, 4f
3:
    addi s4, s4, 1
4:
    addi s2, s2, 1
    bltu s2, s3, 2b
    SIGR s4                         // 0 errors
    jal ra, uart_settle
    andi a0, a0, 0x61
    SIGR a0                         // 0x60

// ---------------- Transmit FIFO reset (8.5: FCR[2] clears the XMIT FIFO, not the shift register) ----------------
// Two characters queued behind one in the shift register: the reset leaves the FIFO empty (THRE), the
// character in the shift register finishes, and the queued ones are never sent.
    jal ra, uart_quiesce
    UW UART_FCR, 0x07
    UW UART_THR, 0x61
    UW UART_THR, 0x62
    UW UART_THR, 0x63
    WAIT_LSR 0x40, 0x00
    UW UART_FCR, 0x05
    CHKM UART_LSR, 0x61             // 0x20: FIFO empty, 0x61 still being sent
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x61
    jal ra, uart_settle
    SIGR a0                         // 0x60: 0x62 and 0x63 were discarded
    UW UART_THR, 0x64               // the FIFO still works
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x64
    jal ra, uart_settle
    SIGR a0                         // 0x60: sent once

// Reset with the FIFO empty and a character in the shift register: no effect on that character.
    jal ra, uart_quiesce
    UW UART_FCR, 0x01
    UW UART_THR, 0x71
    WAIT_LSR 0x40, 0x00
    UW UART_FCR, 0x05
    CHKM UART_LSR, 0x61             // 0x20
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x71
    jal ra, uart_settle
    SIGR a0                         // 0x60

// ---------------- FIFO enable changes clear the FIFOs (8.5 FCR[0]) ----------------
// Disabling the FIFOs with a character queued: the queued character is discarded, the one in the
// shift register is received (into RBR, FIFOs now off), and re-enabling leaves a working, empty FIFO.
    jal ra, uart_quiesce
    UW UART_FCR, 0x07
    UW UART_THR, 0x81
    UW UART_THR, 0x82
    WAIT_LSR 0x40, 0x00
    UW UART_FCR, 0x00
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x81
    jal ra, uart_settle
    SIGR a0                         // 0x60: 0x82 discarded
    UW UART_FCR, 0x01
    CHK UART_LSR                    // 0x60
    UW UART_THR, 0x83
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x83
    jal ra, uart_settle
    SIGR a0                         // 0x60

// Enabling the FIFOs while a character waits in THR (16450 mode): THR is the top of the XMIT FIFO,
// so that character is discarded, and it must not appear when the FIFOs are disabled again.
    jal ra, uart_quiesce
    UW UART_THR, 0x91
    UW UART_THR, 0x92               // waits in THR
    UW UART_FCR, 0x01
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 0x91
    jal ra, uart_settle
    SIGR a0                         // 0x60
    UW UART_FCR, 0x00
    WAIT_HALF_CHARS 4
    CHK UART_LSR                    // 0x60: 0x92 never sent

// ---------------- Transmit FIFO reset at every phase of a character ----------------
// FCR[2] is written k cycles (nops) after a character is written, for k = 0..511, which covers
// every 16x-oversampled phase of more than one character at divisor 1.  Each time, the character
// must be received intact, once, and TEMT must come when the character ends: no later than one
// character after the THR write or the FCR write, whichever is later, plus 1/8 character.  The
// start bit is not aligned to the baud clock, so the sweep runs four times with the character
// written d = 0..3 cycles later.  Entries: number of failing (d, k) (0), first failing k (-1 if none).
    jal ra, uart_quiesce
    li a0, 1
    jal ra, uart_set_divisor
    jal ra, uart_calibrate
    UW UART_FCR, 0x01
    li s3, 0                        // failures
    li s4, -1                       // first failing k
    li s8, 0                        // d
sweep_fcr2_d:
    li s2, 0                        // k
sweep_fcr2:
    NOPS s8
    csrr s5, mcycle
    li t2, 0x5A
    sb t2, UART_THR(s0)
    NOPS s2
    li t2, 0x05
    sb t2, UART_FCR(s0)
    csrr s6, mcycle
    sub s6, s6, s5                  // cycles until the FCR write
    WAIT_LSR 0x40, 0x40
    li t2, 0xBAD
    beq a0, t2, 5f
    csrr s7, mcycle
    sub s7, s7, s5                  // cycles until TEMT
    mv t2, s1
    bgeu t2, s6, 6f
    mv t2, s6
6:
    srli t3, s1, 3
    add t2, t2, t3
    bltu t2, s7, 5f                 // TEMT late
    WAIT_LSR 0x01, 0x01
    li t2, 0xBAD
    beq a0, t2, 5f
    andi t2, a0, 0x1E
    bnez t2, 5f                     // error flags
    lbu t2, UART_RBR(s0)
    li t3, 0x5A
    bne t2, t3, 5f
    WAIT_HALF_CHARS 4
    lbu t2, UART_LSR(s0)
    andi t2, t2, 0x01
    beqz t2, 7f                     // no extra character
5:
    addi s3, s3, 1
    bgez s4, 8f
    mv s4, s2
8:
    jal ra, uart_quiesce
    UW UART_FCR, 0x01
7:
    addi s2, s2, 1
    li t2, 512
    bltu s2, t2, sweep_fcr2
    addi s8, s8, 1
    li t2, 4
    bltu s8, t2, sweep_fcr2_d
    SIGR s3                         // 0
    SIGR s4                         // -1

    jal ra, uart_quiesce

END_TESTS

UART_HELPERS

.data
.align 2
// (data, LCR while transmitting, LCR while receiving, pad)
xfer_table:
    .byte 0x01, 0x1B, 0x0B, 0   // 0: even parity bit 1 checked as odd: PE
    .byte 0x03, 0x1B, 0x0B, 0   // 1: even parity bit 0 checked as odd: PE
    .byte 0x03, 0x1B, 0x1B, 0   // 2: even both ways: no error
    .byte 0x00, 0x2B, 0x1B, 0   // 3: stick parity 1 checked as even (0 expected): PE
    .byte 0x00, 0x2B, 0x0B, 0   // 4: stick parity 1 checked as odd (1 expected): no error
    .byte 0x00, 0x3B, 0x0B, 0   // 5: stick parity 0 checked as odd (1 expected): PE
    .byte 0x00, 0x3B, 0x1B, 0   // 6: stick parity 0 checked as even (0 expected): no error
    .byte 0x01, 0x2B, 0x0B, 0   // 7: stick parity 1 checked as odd (0 expected): PE
    .byte 0x01, 0x3B, 0x1B, 0   // 8: stick parity 0 checked as even (1 expected): PE
    .byte 0x01, 0x1B, 0x2B, 0   // 9: even parity bit 1 checked as stick 1: no error
    .byte 0x01, 0x1B, 0x3B, 0   // 10: even parity bit 1 checked as stick 0: PE
    .byte 0x00, 0x1B, 0x2B, 0   // 11: even parity bit 0 checked as stick 1: PE
    .byte 0x00, 0x1B, 0x3B, 0   // 12: even parity bit 0 checked as stick 0: no error
    .byte 0xA5, 0x2B, 0x2B, 0   // 13: stick 1 both ways
    .byte 0xA5, 0x3B, 0x3B, 0   // 14: stick 0 both ways
    .byte 0x1F, 0x18, 0x08, 0   // 15: 5 bits: even parity bit 1 checked as odd: PE
    .byte 0xE0, 0x18, 0x18, 0   // 16: 5 bits: bits 7:5 are not sent and not in the parity
    .byte 0x7F, 0x0A, 0x1A, 0   // 17: 7 bits: odd parity bit 0 checked as even: PE
    .byte 0x2A, 0x29, 0x19, 0   // 18: 6 bits: stick 1 checked as even (1 expected): no error
    .byte 0x2A, 0x39, 0x19, 0   // 19: 6 bits: stick 0 checked as even (1 expected): PE
    .byte 0x15, 0x01, 0x04, 0   // 20: 6N1 sent, 5N2 received: data bit 5 (0) is the stop bit: FE
    .byte 0x35, 0x01, 0x04, 0   // 21: data bit 5 is 1: no error
    .byte 0x3F, 0x03, 0x06, 0   // 22: 8N1 sent, 7N2 received: data bit 7 (0) is the stop bit: FE
    .byte 0x81, 0x1B, 0x07, 0   // 23: 8E1 sent, 8N2 received: the parity bit (0) is the stop bit: FE
    .byte 0xBF, 0x03, 0x06, 0   // 24: 8N1 sent, 7N2 received: data bit 7 is 1: no error
    .byte 0x80, 0x1B, 0x07, 0   // 25: 8E1 sent, 8N2 received: the parity bit is 1: no error
    .byte 0x5A, 0x03, 0x03, 0   // 26: 8N1: the receiver resynchronized
    .byte 0x55, 0x00, 0x00, 0   // 27: 5N1
    .byte 0xAA, 0x05, 0x05, 0   // 28: 6N2
    .byte 0xC3, 0x0F, 0x0F, 0   // 29: 8O2
    .byte 0x4B, 0x1E, 0x1E, 0   // 30: 7E2
    .byte 0x96, 0x0C, 0x0C, 0   // 31: 5O1.5
xfer_table_end:

// LCR values for the frame length measurements
frame_table:
    .byte 0x00                  // 5N1:   7 bits
    .byte 0x04                  // 5N1.5: 7.5 bits
    .byte 0x01                  // 6N1:   8 bits
    .byte 0x05                  // 6N2:   9 bits
    .byte 0x02                  // 7N1:   9 bits
    .byte 0x0E                  // 7O2:   11 bits
    .byte 0x1B                  // 8E1:   11 bits
    .byte 0x07                  // 8N2:   11 bits
    .byte 0x0F                  // 8O2:   12 bits
    .byte 0x0C                  // 5O1.5: 8.5 bits
frame_table_end:

TEST_STACK_AND_DATA

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each).  SIG_NEXT in WALLY-TEST-LIB.h checks
//   each entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
// character formats: LSR[4:0], RBR, extra character
WORD 0x05, 0x01, 0      // 0
WORD 0x05, 0x03, 0      // 3
WORD 0x01, 0x03, 0      // 6
WORD 0x05, 0x00, 0      // 9
WORD 0x01, 0x00, 0      // 12
WORD 0x05, 0x00, 0      // 15
WORD 0x01, 0x00, 0      // 18
WORD 0x05, 0x01, 0      // 21
WORD 0x05, 0x01, 0      // 24
WORD 0x01, 0x01, 0      // 27
WORD 0x05, 0x01, 0      // 30
WORD 0x05, 0x00, 0      // 33
WORD 0x01, 0x00, 0      // 36
WORD 0x01, 0xA5, 0      // 39
WORD 0x01, 0xA5, 0      // 42
WORD 0x05, 0x1F, 0      // 45
WORD 0x01, 0x00, 0      // 48
WORD 0x05, 0x7F, 0      // 51
WORD 0x01, 0x2A, 0      // 54
WORD 0x05, 0x2A, 0      // 57
WORD 0x09, 0x15, 0x11F  // 60: FE, then the resynchronized all-ones character
WORD 0x01, 0x15, 0      // 63
WORD 0x09, 0x3F, 0x17F  // 66
WORD 0x09, 0x81, 0x1FF  // 69
WORD 0x01, 0x3F, 0      // 72
WORD 0x01, 0x80, 0      // 75
WORD 0x01, 0x5A, 0      // 78
WORD 0x01, 0x15, 0      // 81
WORD 0x01, 0x2A, 0      // 84
WORD 0x01, 0xC3, 0      // 87
WORD 0x01, 0x4B, 0      // 90
WORD 0x01, 0x16, 0      // 93
// format change during a character
WORD 0x01, 0x5A, 0      // 96
// frame lengths, 2 x bit times
WORD 14, 15, 16, 18, 18, 22, 22, 22, 24, 17     // 99
// divisor ratios
WORD 20, 63, 127        // 109
// THRE and TEMT
WORD 0x20, 0x00, 0x20, 0x41, 0x42, 0x60         // 112
// 16-byte transmit FIFO
WORD 0x00, 0, 0x60      // 118
WORD 0, 0x60            // 121: full XMIT FIFO
// transmit FIFO reset
WORD 0x20, 0x61, 0x60, 0x64, 0x60               // 123
WORD 0x20, 0x71, 0x60   // 128
// FIFO enable changes
WORD 0x81, 0x60, 0x60, 0x83, 0x60               // 131
WORD 0x91, 0x60, 0x60   // 136
// transmit FIFO reset sweep
WORD 0, -1              // 139
WORD 0x0B               // 141: ecall from test termination
expected_signature_end:
