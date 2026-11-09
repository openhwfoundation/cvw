///////////////////////////////////////////
// WALLY-uart-status-01.S
//
// Purpose: PC16550D 8.4 FIFO-error acknowledgement and 8.11 conditional THRE delay.
//          Timing checks use calibrated character times, not a fixed CPU clock count.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2026 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"
#include "WALLY-uart.h"

INIT_TESTS
TRAP_HANDLER m
    li s0, UART
    jal ra, uart_quiesce
    li a0, 32
    jal ra, uart_set_divisor
    jal ra, uart_calibrate

// The sole bad character remains readable after its error is acknowledged.
    UW UART_FCR, 0x07
    li a0, 0x01
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed
    CHK UART_LSR                    // 0: E5, parity error and FIFO error
    CHK UART_LSR                    // 1: 61, error acknowledged without popping data
    CHK UART_RBR                    // 2: 01, data preserved
    CHK UART_LSR                    // 3: 60

// Acknowledging the head must preserve an error in the next slot. The second send
// polls LSR before arrival, deliberately acknowledging the first character's error.
    li a0, 0x02
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed
    li a0, 0x03
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed
    CHK UART_LSR                    // 4: E1, next slot still has an error
    CHK UART_LSR                    // 5: E1, repeat must not acknowledge next slot
    CHK UART_RBR                    // 6: 02
    CHK UART_LSR                    // 7: E5, second error is now at the head
    CHK UART_LSR                    // 8: 61
    CHK UART_RBR                    // 9: 03

// FIFO error is zero in 16450 mode even without an intervening LSR read.
    li a0, 0x04
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed
    UW UART_FCR, 0x00
    CHKM UART_LSR, 0x81             // 10: 00, no FIFO error or data ready
    UW UART_FCR, 0x01
    CHKM UART_LSR, 0x81             // 11: 00, stale error does not return
    jal ra, uart_quiesce

// The initial interrupt after enabling FIFOs is immediate. A single-byte refill
// delays THRE until one character minus the last stop bit (9 bits for 8N1).
// Check well inside that interval (half a character), and after it, with margin
// for APB access and the character calibration overhead.
    UW UART_FCR, 0x07
    UW UART_IER, 0x02
    CHK UART_IIR                    // 12: C2, initial interrupt
    CHK UART_IIR                    // 13: C1, acknowledged
    UW UART_THR, 0x55
    WAIT_HALF_CHARS 1
    CHK UART_IIR                    // 14: C1, single-byte delay still active
    CHKM UART_LSR, 0x20             // 15: 00, delayed empty indication
    WAIT_HALF_CHARS 2
    CHK UART_IIR                    // 16: C2, delay expired
    CHK UART_IIR                    // 17: C1, reading IIR clears it

// Keep a frame shifting while two more bytes are enqueued together. On draining
// those two, THRE must assert while the final frame is still near its start.
    UW UART_THR, 0x56
    WAIT_LSR 0x40, 0x00
    UW UART_THR, 0x57
    UW UART_THR, 0x58
    WAIT_LSR 0x20, 0x20
    CHK UART_IIR                    // 18: C2, no delay after a multi-byte refill
    CHKM UART_LSR, 0x40             // 19: 00, last frame has not finished
    WAIT_HALF_CHARS 1
    CHKM UART_LSR, 0x40             // 20: 00, still shifting half a character later
    WAIT_LSR 0x40, 0x40

// A new one-byte refill after that empty indication must delay again.
    UW UART_THR, 0x59
    WAIT_HALF_CHARS 1
    CHK UART_IIR                    // 21: C1
    WAIT_HALF_CHARS 2
    CHK UART_IIR                    // 22: C2

// A FIFO reset releases the delayed indication immediately, without stopping TX.
    UW UART_THR, 0x5A
    WAIT_LSR 0x40, 0x00
    UW UART_FCR, 0x05
    CHK UART_IIR                    // 23: C2
    CHKM UART_LSR, 0x40             // 24: 00, shifter still active
    jal ra, uart_quiesce

// 16450 mode keeps immediate THRE when the holding register empties.
    UW UART_IER, 0x02
    UR UART_IIR
    UW UART_THR, 0x5B
    WAIT_HALF_CHARS 1
    CHK UART_IIR                    // 25: 02
    jal ra, uart_quiesce

// The delay follows the programmed frame length, rather than always taking nine
// bits. For 5N1 it expires at six bit times, before this 7.5-bit observation.
    UW UART_FCR, 0x07
    UW UART_IER, 0x02
    UR UART_IIR
    UW UART_LCR, 0x00
    UW UART_THR, 0x15
    srli a0, s1, 1
    srli t2, s1, 2
    add a0, a0, t2
    jal ra, uart_delay
    CHK UART_IIR                    // 26: C2
    jal ra, uart_quiesce

// For 8E2 the delay includes parity and the first stop bit (eleven bits), so it
// must still be active after ten bit times and expired after fifteen.
    UW UART_FCR, 0x07
    UW UART_IER, 0x02
    UR UART_IIR
    UW UART_LCR, 0x1F
    UW UART_THR, 0x5C
    WAIT_HALF_CHARS 2
    CHK UART_IIR                    // 27: C1
    WAIT_HALF_CHARS 1
    CHK UART_IIR                    // 28: C2
    jal ra, uart_quiesce

END_TESTS
UART_HELPERS
TEST_STACK_AND_DATA

.align REGSHIFT
expected_signature:
WORD 0xE5, 0x61, 0x01, 0x60
WORD 0xE1, 0xE1, 0x02, 0xE5, 0x61, 0x03
WORD 0x00, 0x00
WORD 0xC2, 0xC1, 0xC1, 0x00, 0xC2, 0xC1
WORD 0xC2, 0x00, 0x00
WORD 0xC1, 0xC2, 0xC2, 0x00, 0x02
WORD 0xC2, 0xC1, 0xC2
WORD 0x0B
expected_signature_end:
