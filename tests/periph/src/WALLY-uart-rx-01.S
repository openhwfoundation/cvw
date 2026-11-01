///////////////////////////////////////////
// WALLY-uart-rx-01.S
//
// Purpose: UART receiver: receive buffer overrun, the 16-byte receive FIFO and its overrun, empty
//          reads, receive FIFO reset (FCR[1]), FIFO enable changes, trigger levels, the character
//          timeout, line status errors in the FIFO (LSR[7] and errors revealed at the top of the
//          FIFO), and sweeps of register reads against character arrival and modem input changes.
//          Expected values follow the PC16550D datasheet (see WALLY-uart.h).
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
    jal ra, uart_quiesce
    li a0, 2
    jal ra, uart_set_divisor
    jal ra, uart_calibrate

// ---------------- Receive buffer and overrun, FIFOs off (8.4: DR, OE) ----------------
// An LSR read clears OE, PE, FE, and BI, so where a test checks them it waits by the cycle counter
// rather than by polling LSR after the character arrives.
    UW UART_THR, 0x11
    WAIT_LSR 0x40, 0x40
    CHK UART_LSR                    // 0: 0x61
    UW UART_THR, 0x12               // arrives before 0x11 is read
    WAIT_HALF_CHARS 3
    CHK UART_LSR                    // 1: 0x63, overrun
    CHK UART_RBR                    // 2: 0x12, the new character replaced the old one
    CHK UART_LSR                    // 3: 0x60, OE cleared by the LSR read, DR by the RBR read

// ---------------- Reads of an empty receiver do not disturb it ----------------
    UR UART_RBR
    UR UART_RBR
    UR UART_RBR
    CHK UART_LSR                    // 4: 0x60
    UW UART_THR, 0x13
    WAIT_LSR 0x40, 0x40
    CHK UART_LSR                    // 5: 0x61
    CHK UART_RBR                    // 6: 0x13
    CHK UART_LSR                    // 7: 0x60

// ---------------- 16-byte receive FIFO (8.5, 8.11) ----------------
// 16 characters fill the FIFO without overrun and come out in order.
    UW UART_FCR, 0x07
    li s2, 0x20
    li s3, 0x30
1:
    sb s2, UART_THR(s0)
    addi s2, s2, 1
    bltu s2, s3, 1b
    WAIT_HALF_CHARS 34
    CHK UART_LSR                    // 8: 0x61, no overrun
    li s2, 0x20
    li s4, 0
2:
    lbu t2, UART_RBR(s0)
    beq t2, s2, 3f
    addi s4, s4, 1
3:
    addi s2, s2, 1
    bltu s2, s3, 2b
    SIGR s4                         // 9: 0 errors
    CHK UART_LSR                    // 10: 0x60

// A 17th character overruns: OE is reported at once, the character is lost, and the FIFO keeps the 16.
    UW UART_FCR, 0x07
    li s2, 0x40
    li s3, 0x51
1:
    sb s2, UART_THR(s0)
    addi s2, s2, 1
    bltu s2, s3, 1b
    WAIT_HALF_CHARS 36
    CHK UART_LSR                    // 11: 0x63
    CHK UART_LSR                    // 12: 0x61, OE cleared
    li s2, 0x40
    li s3, 0x50
    li s4, 0
2:
    lbu t2, UART_RBR(s0)
    beq t2, s2, 3f
    addi s4, s4, 1
3:
    addi s2, s2, 1
    bltu s2, s3, 2b
    SIGR s4                         // 13: 0 errors
    CHK UART_LSR                    // 14: 0x60, 0x50 was not stored

// Reads of an empty FIFO do not disturb it.
    UR UART_RBR
    UR UART_RBR
    UR UART_RBR
    CHK UART_LSR                    // 15: 0x60
    UW UART_THR, 0x14
    WAIT_LSR 0x40, 0x40
    CHK UART_RBR                    // 16: 0x14
    CHK UART_LSR                    // 17: 0x60

// ---------------- Receive FIFO reset (8.5: FCR[1] clears the RCVR FIFO, not the shift register) ----------------
    UW UART_THR, 0x31
    UW UART_THR, 0x32
    UW UART_THR, 0x33
    jal ra, uart_settle
    SIGR a0                         // 18: 0x61
    UW UART_FCR, 0x03
    CHK UART_LSR                    // 19: 0x60
    UW UART_THR, 0x34
    WAIT_LSR 0x40, 0x40
    CHK UART_RBR                    // 20: 0x34
    CHK UART_LSR                    // 21: 0x60
// Reset halfway through a character: that character is still received.
    UW UART_THR, 0x35
    WAIT_LSR 0x40, 0x00
    WAIT_HALF_CHARS 1
    UW UART_FCR, 0x03
    WAIT_LSR 0x40, 0x40
    WAIT_LSR 0x01, 0x01
    CHK UART_RBR                    // 22: 0x35
    CHK UART_LSR                    // 23: 0x60

// ---------------- FIFO enable changes clear the receiver (8.5 FCR[0]) ----------------
// RBR in 16450 mode is the top of the RCVR FIFO, so a character waiting there is cleared too.
    jal ra, uart_quiesce
    UW UART_THR, 0x41
    WAIT_LSR 0x40, 0x40             // 0x41 waits in RBR
    UW UART_FCR, 0x01
    CHK UART_LSR                    // 24: 0x60
    UW UART_THR, 0x42
    WAIT_LSR 0x40, 0x40
    CHK UART_RBR                    // 25: 0x42
    CHK UART_LSR                    // 26: 0x60
    UW UART_THR, 0x43
    UW UART_THR, 0x44
    jal ra, uart_settle
    UW UART_FCR, 0x00
    CHK UART_LSR                    // 27: 0x60
    UW UART_THR, 0x45
    WAIT_LSR 0x40, 0x40
    CHK UART_RBR                    // 28: 0x45
    CHK UART_LSR                    // 29: 0x60

// ---------------- With DLAB = 1, address 0 reads DLL and does not pop the FIFO ----------------
    UW UART_FCR, 0x07
    UW UART_THR, 0x51
    UW UART_THR, 0x52
    jal ra, uart_settle
    UW UART_LCR, 0x83
    CHK UART_DLL                    // 30: 0x02
    UW UART_LCR, 0x03
    CHK UART_RBR                    // 31: 0x51
    CHK UART_RBR                    // 32: 0x52
    CHK UART_LSR                    // 33: 0x60

// ---------------- Trigger levels (8.5 FCR[7:6], 8.11: received data available) ----------------
// For each level L: L-1 characters raise no interrupt, the L-th does, and reading one character
// (dropping below L) clears it.  Entries per level: IIR, IIR, IIR, LSR after draining.
    UW UART_IER, 0x01
    la s2, trigger_table
    la s3, trigger_table_end
trig_loop:
    lbu t2, 0(s2)
    sb t2, UART_FCR(s0)             // level, reset both FIFOs, enable
    lbu s4, 1(s2)                   // L - 1
    li s5, 0x60                     // character to send
    mv s6, s4
1:
    beqz s6, 2f
    sb s5, UART_THR(s0)
    addi s5, s5, 1
    addi s6, s6, -1
    j 1b
2:
    jal ra, uart_settle
    CHK UART_IIR                    // 0xC1: below the level
    sb s5, UART_THR(s0)
    WAIT_LSR 0x40, 0x40
    WAIT_HALF_CHARS 1
    CHK UART_IIR                    // 0xC4: at the level
    UR UART_RBR
    CHK UART_IIR                    // 0xC1: below the level again
3:
    beqz s4, 4f
    UR UART_RBR
    addi s4, s4, -1
    j 3b
4:
    CHK UART_LSR                    // 0x60
    addi s2, s2, 2
    bltu s2, s3, trig_loop

// Lowering the trigger level below the number of characters waiting raises the interrupt.
    UW UART_FCR, 0xC7               // level 14
    UW UART_THR, 0x6A
    UW UART_THR, 0x6B
    jal ra, uart_settle
    CHK UART_IIR                    // 50: 0xC1
    UW UART_FCR, 0x01               // level 1, no reset
    CHK UART_IIR                    // 51: 0xC4
    UR UART_RBR
    UR UART_RBR

// ---------------- Character timeout (8.11) ----------------
// With characters in the FIFO below the trigger level, IIR = 0xCC once no character has been
// received and none read for 4 character times.  A read clears it and restarts the timer.  Times
// below are counted from TEMT (the end of the last character's stop bit) or from the RBR read.
    UW UART_FCR, 0x87               // trigger level 8
    UW UART_IER, 0x01
    UW UART_THR, 0x61
    UW UART_THR, 0x62
    WAIT_LSR 0x40, 0x40
    WAIT_HALF_CHARS 5
    CHK UART_IIR                    // 52: 0xC1 at 2.5 character times
    WAIT_HALF_CHARS 2
    CHK UART_IIR                    // 53: 0xC1 at 3.5
    WAIT_HALF_CHARS 3
    CHK UART_IIR                    // 54: 0xCC at 5
    CHK UART_RBR                    // 55: 0x61
    CHK UART_IIR                    // 56: 0xC1, cleared by the read
    WAIT_HALF_CHARS 7
    CHK UART_IIR                    // 57: 0xC1 at 3.5 after the read
    WAIT_HALF_CHARS 3
    CHK UART_IIR                    // 58: 0xCC at 5 after the read
    CHK UART_RBR                    // 59: 0x62
    WAIT_HALF_CHARS 12
    CHK UART_IIR                    // 60: 0xC1, FIFO empty: no timeout
    CHK UART_LSR                    // 61: 0x60
// IER[0] = 0 hides the timeout; enabling it shows it.
    UW UART_IER, 0x00
    UW UART_THR, 0x63
    WAIT_LSR 0x40, 0x40
    WAIT_HALF_CHARS 12
    CHK UART_IIR                    // 62: 0xC1
    UW UART_IER, 0x01
    CHK UART_IIR                    // 63: 0xCC
    CHK UART_RBR                    // 64: 0x63
    CHK UART_IIR                    // 65: 0xC1
// A newly received character restarts the timer.
    UW UART_THR, 0x65
    WAIT_LSR 0x40, 0x40
    WAIT_HALF_CHARS 4
    UW UART_THR, 0x66
    WAIT_LSR 0x40, 0x40
    WAIT_HALF_CHARS 5
    CHK UART_IIR                    // 66: 0xC1 at 2.5 after the second character
    WAIT_HALF_CHARS 5
    CHK UART_IIR                    // 67: 0xCC at 5
    CHK UART_RBR                    // 68: 0x65
    CHK UART_RBR                    // 69: 0x66
    CHK UART_LSR                    // 70: 0x60
// No timeout with the FIFOs off: a waiting character is reported as received data available.
    jal ra, uart_quiesce
    UW UART_IER, 0x01
    UW UART_THR, 0x64
    WAIT_LSR 0x40, 0x40
    WAIT_HALF_CHARS 12
    CHK UART_IIR                    // 71: 0x04
    CHK UART_RBR                    // 72: 0x64
    CHK UART_IIR                    // 73: 0x01
    UW UART_IER, 0x00

// ---------------- Line status errors in the FIFO (8.4: PE and LSR[7]) ----------------
// An error belongs to its character and is revealed when that character reaches the top of the FIFO;
// LSR[7] is set while any character in the FIFO has an error.  The FIFO receives A (good), B (parity
// error), C (good); polling LSR for TEMT while they arrive must not disturb B's error.
    jal ra, uart_quiesce
    UW UART_FCR, 0xC7               // trigger level 14
    UW UART_IER, 0x04               // receiver line status interrupt only
    li a0, 0x71
    li a1, 0x1B
    li a2, 0x1B
    jal ra, uart_send_switch        // A
    li a0, 0x01
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch        // B: even parity checked as odd
    li a0, 0x73
    li a1, 0x1B
    li a2, 0x1B
    jal ra, uart_send_switch        // C
    CHK UART_IIR                    // 74: 0xC1, A at the top has no error
    CHK UART_LSR                    // 75: 0xE1, LSR[7]: B in the FIFO has an error
    CHK UART_RBR                    // 76: 0x71
    CHK UART_IIR                    // 77: 0xC6, B at the top: line status interrupt
    CHK UART_LSR                    // 78: 0xE5, PE
    CHK UART_IIR                    // 79: 0xC1, cleared by the LSR read
    CHK UART_RBR                    // 80: 0x01
    CHK UART_LSR                    // 81: 0x61, B's acknowledged error must not leave LSR[7] set
    CHK UART_LSR                    // 82: 0x61, no error left in the FIFO
    CHK UART_RBR                    // 83: 0x73
    CHK UART_LSR                    // 84: 0x60
    UW UART_LCR, 0x03

// ---------------- Line status errors, FIFOs off (8.4) ----------------
    jal ra, uart_quiesce
    li a0, 0x01
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed
    CHK UART_LSR                    // 85: 0x65, PE with the character
    CHK UART_RBR                    // 86: 0x01
    CHK UART_LSR                    // 87: 0x60, cleared by the read
    li a0, 0x02
    li a1, 0x1B
    li a2, 0x1B
    jal ra, uart_send_switch        // good character, left unread
    li a0, 0x01
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed  // parity error, overruns the first
    CHK UART_LSR                    // 88: 0x67, OE and PE
    CHK UART_RBR                    // 89: 0x01
    CHK UART_LSR                    // 90: 0x60
    UW UART_LCR, 0x03

// ---------------- Sweeps of register reads against character arrival and modem input changes ----------------
// At divisor 1, a register read is placed k cycles (nops) after an event, for k = 0..511, which
// covers the arrival of a character at every cycle offset.  A character's start bit is not aligned
// to the baud clock, so its arrival time moves by up to a baud period with the cycle it is written
// in; each sweep therefore runs four times, writing the character d = 0..3 cycles later.  Each sweep
// gives two entries: the number of failing (d, k) (0) and the first failing k (-1 if none).
    jal ra, uart_quiesce
    li a0, 1
    jal ra, uart_set_divisor
    jal ra, uart_calibrate

// RBR read against the arrival of the next character: A is in the FIFO, B is sent, and A is read k
// cycles later.  A read must pop exactly one character whenever it happens.
    UW UART_FCR, 0x07
    li s3, 0
    li s4, -1
    li s8, 0
sweep_rbr_d:
    li s2, 0
sweep_rbr:
    UW UART_THR, 0x3C
    WAIT_LSR 0x01, 0x01             // A has arrived
    NOPS s8
    UW UART_THR, 0xC3
    NOPS s2
    lbu s5, UART_RBR(s0)            // A
    WAIT_LSR 0x40, 0x40
    WAIT_LSR 0x01, 0x01
    lbu s6, UART_RBR(s0)            // B
    WAIT_HALF_CHARS 4
    lbu t2, UART_LSR(s0)
    andi t2, t2, 0x01               // nothing more
    li t3, 0x3C
    bne s5, t3, 5f
    li t3, 0xC3
    bne s6, t3, 5f
    beqz t2, 6f
5:
    addi s3, s3, 1
    bgez s4, 7f
    mv s4, s2
7:
    jal ra, uart_quiesce
    UW UART_FCR, 0x07
6:
    addi s2, s2, 1
    li t2, 512
    bltu s2, t2, sweep_rbr
    addi s8, s8, 1
    li t2, 4
    bltu s8, t2, sweep_rbr_d
    SIGR s3                         // 91: 0
    SIGR s4                         // 92: -1

// LSR read against the arrival of a character with a parity error (FIFOs off): the error must be
// seen with data ready, whether the read at k lands before or after the arrival.
    jal ra, uart_quiesce
    li s3, 0
    li s4, -1
    li s8, 0
sweep_lsr_err_d:
    li s2, 0
sweep_lsr_err:
    UW UART_LCR, 0x1B
    NOPS s8
    UW UART_THR, 0x01
    WAIT_LSR 0x40, 0x00
    UW UART_LCR, 0x0B               // checked as odd: parity error
    NOPS s2
    lbu s5, UART_LSR(s0)            // read at k
    WAIT_HALF_CHARS 4
    lbu s6, UART_LSR(s0)            // read after the character
    andi t2, s5, 0x01
    bnez t2, 1f
    mv s5, s6                       // the read at k was before the arrival
1:
    andi s5, s5, 0x05
    lbu t2, UART_RBR(s0)
    li t3, 0x05
    beq s5, t3, 6f
    addi s3, s3, 1
    bgez s4, 6f
    mv s4, s2
6:
    jal ra, uart_quiesce
    addi s2, s2, 1
    li t2, 512
    bltu s2, t2, sweep_lsr_err
    addi s8, s8, 1
    li t2, 4
    bltu s8, t2, sweep_lsr_err_d
    SIGR s3                         // 93: 0
    SIGR s4                         // 94: -1

// LSR read against the arrival of the next, good character (FIFOs off): A (parity error) has been
// read from RBR but its status not yet read; B is sent and LSR is read k cycles later.  That read
// reports A's error and clears it, so the read after B must show no error.
    li s3, 0
    li s4, -1
    li s8, 0
sweep_lsr_clr_d:
    li s2, 0
sweep_lsr_clr:
    li a0, 0x01
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed  // A, parity error; LCR stays odd
    lbu t2, UART_RBR(s0)
    NOPS s8
    UW UART_THR, 0x01               // B, odd parity: good
    NOPS s2
    lbu s5, UART_LSR(s0)            // read at k
    WAIT_HALF_CHARS 4
    lbu s6, UART_LSR(s0)            // read after B
    lbu t2, UART_RBR(s0)
    andi s5, s5, 0x04
    andi s6, s6, 0x04
    beqz s5, 5f                     // A's error must be in the read at k
    beqz s6, 6f                     // and not after B
5:
    addi s3, s3, 1
    bgez s4, 6f
    mv s4, s2
6:
    jal ra, uart_quiesce
    addi s2, s2, 1
    li t2, 512
    bltu s2, t2, sweep_lsr_clr
    addi s8, s8, 1
    li t2, 4
    bltu s8, t2, sweep_lsr_clr_d
    SIGR s3                         // 95: 0
    SIGR s4                         // 96: -1

// MSR read against a modem input change: MCR toggles RTS (looped back to CTS) and MSR is read n
// nops later (n = 0..23, inline) and again right after.  DCTS must appear in exactly one of the two
// reads.  In loopback the change reaches MSR a couple of cycles after the MCR write, before a
// following bus read can arrive, so this cannot catch a read that coincides with the change; it
// checks that a delta is reported once and cleared by the read.
.macro MSR_TRY n
    xori s7, s7, 0x02               // toggle RTS
    sb s7, UART_MCR(s0)
    .rept \n
    nop
    .endr
    lbu a0, UART_MSR(s0)
    lbu a1, UART_MSR(s0)
    li a2, \n
    jal ra, msr_check
.endm
    li s3, 0
    li s4, -1
    li s7, 0x10                     // MCR: loopback, RTS off
    .irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23
    MSR_TRY \n
    .endr
    SIGR s3                         // 97: 0
    SIGR s4                         // 98: -1
    j msr_done

// a0, a1 = the two MSR reads, a2 = n.  Counts a failure in s3, first failing n in s4.
msr_check:
    mv a3, ra
    andi a0, a0, 0x01
    andi a1, a1, 0x01
    add a0, a0, a1
    li t2, 1
    beq a0, t2, 1f
    addi s3, s3, 1
    bgez s4, 1f
    mv s4, a2
1:
    WAIT_HALF_CHARS 1
    lbu t2, UART_MSR(s0)            // clear any late delta
    mv ra, a3
    ret
msr_done:

    jal ra, uart_quiesce

END_TESTS

UART_HELPERS

.data
// (FCR value, trigger level - 1)
trigger_table:
    .byte 0x07, 0
    .byte 0x47, 3
    .byte 0x87, 7
    .byte 0xC7, 13
trigger_table_end:

TEST_STACK_AND_DATA

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each).  SIG_NEXT in WALLY-TEST-LIB.h checks
//   each entry as soon as it is written; a mismatch halts the test and reports the entry index below.
//   Entries 34-49 are the trigger level checks (four per level).
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x61, 0x63, 0x12, 0x60                 // 0: receive buffer overrun
WORD 0x60, 0x61, 0x13, 0x60                 // 4: empty reads
WORD 0x61, 0, 0x60                          // 8: 16-byte FIFO
WORD 0x63, 0x61, 0, 0x60                    // 11: FIFO overrun
WORD 0x60, 0x14, 0x60                       // 15: empty FIFO reads
WORD 0x61, 0x60, 0x34, 0x60                 // 18: FCR[1]
WORD 0x35, 0x60                             // 22: FCR[1] during a character
WORD 0x60, 0x42, 0x60, 0x60, 0x45, 0x60     // 24: FIFO enable changes
WORD 0x02, 0x51, 0x52, 0x60                 // 30: DLAB
WORD 0xC1, 0xC4, 0xC1, 0x60                 // trigger level 1
WORD 0xC1, 0xC4, 0xC1, 0x60                 // trigger level 4
WORD 0xC1, 0xC4, 0xC1, 0x60                 // trigger level 8
WORD 0xC1, 0xC4, 0xC1, 0x60                 // trigger level 14
WORD 0xC1, 0xC4                             // 50: lowered trigger level
WORD 0xC1, 0xC1, 0xCC, 0x61, 0xC1, 0xC1, 0xCC, 0x62, 0xC1, 0x60  // 52: timeout
WORD 0xC1, 0xCC, 0x63, 0xC1                 // 62: IER[0]
WORD 0xC1, 0xCC, 0x65, 0x66, 0x60           // 66: restarted by a new character
WORD 0x04, 0x64, 0x01                       // 71: FIFOs off
WORD 0xC1, 0xE1, 0x71, 0xC6, 0xE5, 0xC1, 0x01, 0x61, 0x61, 0x73, 0x60  // 74: errors in the FIFO
WORD 0x65, 0x01, 0x60, 0x67, 0x01, 0x60     // 85: errors, FIFOs off
WORD 0, -1                                  // 91: RBR read sweep
WORD 0, -1                                  // 93: LSR error sweep
WORD 0, -1                                  // 95: LSR clear sweep
WORD 0, -1                                  // 97: MSR sweep
WORD 0x0B                                   // ecall from test termination
expected_signature_end:
