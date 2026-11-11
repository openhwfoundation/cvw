///////////////////////////////////////////
// WALLY-uart-intr-01.S
//
// Purpose: UART interrupts and modem status: IIR priority, IER gating, the THRE interrupt and how it
//          is cleared and raised again, receiver line status and received data interrupts, MSR in
//          loopback (mapping, deltas, trailing edge of RI), and the INTR output through the PLIC.
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

// ---------------- Priority (Table IV): line status > received data > THRE > modem status ----------------
// FIFOs off: 0x21 waits in RBR and 0x22 overruns it (OE), the transmitter is empty (THRE), and RTS
// toggles (DCTS).  Clearing each source in turn reveals the next.
    UW UART_THR, 0x21
    WAIT_LSR 0x40, 0x40
    UW UART_THR, 0x22
    WAIT_HALF_CHARS 3               // no LSR polling: it would clear OE
    UW UART_MCR, 0x12
    UW UART_IER, 0x0F
    CHK UART_IIR                    // 0: 0x06 line status
    CHK UART_LSR                    // 1: 0x63, clears OE
    CHK UART_IIR                    // 2: 0x04 received data
    CHK UART_RBR                    // 3: 0x22
    CHK UART_IIR                    // 4: 0x02 THRE
    CHK UART_IIR                    // 5: 0x00 modem status: reading IIR cleared THRE
    CHK UART_MSR                    // 6: 0x11, CTS and DCTS
    CHK UART_IIR                    // 7: 0x01

// ---------------- IER gating (8.7): pending conditions show only when enabled ----------------
    UW UART_IER, 0x00
    UW UART_THR, 0x23               // received data; the THR write also re-arms THRE
    WAIT_LSR 0x40, 0x40
    UW UART_MCR, 0x10               // DCTS
    CHK UART_IIR                    // 8: 0x01
    UW UART_IER, 0x08
    CHK UART_IIR                    // 9: 0x00
    UW UART_IER, 0x02
    CHK UART_IIR                    // 10: 0x02
    UW UART_IER, 0x01
    CHK UART_IIR                    // 11: 0x04
    UW UART_IER, 0x00
    CHK UART_IIR                    // 12: 0x01
    UR UART_RBR
    UR UART_MSR

// ---------------- THRE interrupt (Table IV): set when THR is empty; cleared by reading IIR when it is
// the source, or by writing THR ----------------
    jal ra, uart_quiesce
    UW UART_THR, 0x30               // a THR write, so no earlier IIR read is still pending
    WAIT_LSR 0x40, 0x40
    UR UART_RBR
    UW UART_IER, 0x02
    CHK UART_IIR                    // 13: 0x02, enabled while THR is empty
    CHK UART_IIR                    // 14: 0x01, cleared by the read
    UW UART_THR, 0x31
    WAIT_LSR 0x20, 0x20             // 0x31 moved to the shift register: THR empty again
    CHK UART_IIR                    // 15: 0x02
    WAIT_LSR 0x40, 0x40
    UR UART_RBR
// Clearing and setting IER[1] while THR is empty raises the interrupt again.  Linux's 8250 driver
// probes for this at startup (UART_BUG_THRE) and works around UARTs that do not.
    UW UART_IER, 0x00
    UW UART_IER, 0x02
    CHK UART_IIR                    // 16: 0x02
    CHK UART_IIR                    // 17: 0x01
// Reading IIR while it reports a higher-priority source does not clear THRE.
    UW UART_IER, 0x03
    UW UART_THR, 0x32
    WAIT_LSR 0x40, 0x40
    CHK UART_IIR                    // 18: 0x04
    CHK UART_RBR                    // 19: 0x32
    CHK UART_IIR                    // 20: 0x02
// FIFO mode: THRE means the XMIT FIFO is empty.
    UW UART_IER, 0x02
    UW UART_FCR, 0x07
    UW UART_THR, 0x33
    UW UART_THR, 0x34
    UW UART_THR, 0x35
    CHK UART_IIR                    // 21: 0xC1, FIFO not empty
    WAIT_LSR 0x20, 0x20
    CHK UART_IIR                    // 22: 0xC2, FIFO empty
    jal ra, uart_quiesce
// FIFO mode: resetting the XMIT FIFO (FCR[2]) with characters queued empties it: THRE.
    UW UART_FCR, 0x07
    UW UART_IER, 0x02
    UW UART_THR, 0x36
    UW UART_THR, 0x37
    UW UART_THR, 0x38
    UW UART_FCR, 0x05
    CHK UART_IIR                    // 23: 0xC2
    jal ra, uart_quiesce

// ---------------- Receiver line status interrupt (Table IV): cleared by reading LSR ----------------
    UW UART_IER, 0x04
    UW UART_THR, 0x41
    WAIT_LSR 0x40, 0x40
    UW UART_THR, 0x42               // overruns 0x41
    WAIT_HALF_CHARS 3
    CHK UART_IIR                    // 24: 0x06
    CHK UART_LSR                    // 25: 0x63
    CHK UART_IIR                    // 26: 0x01
    UR UART_RBR
    li a0, 0x01
    li a1, 0x1B
    li a2, 0x0B
    jal ra, uart_send_switch_timed  // parity error
    CHK UART_IIR                    // 27: 0x06
    CHK UART_LSR                    // 28: 0x65
    CHK UART_IIR                    // 29: 0x01
    UR UART_RBR
    UW UART_LCR, 0x03

// ---------------- Received data available, FIFOs off (Table IV): cleared by reading RBR ----------------
    UW UART_IER, 0x01
    UW UART_THR, 0x43
    WAIT_LSR 0x40, 0x40
    CHK UART_IIR                    // 30: 0x04
    CHK UART_RBR                    // 31: 0x43
    CHK UART_IIR                    // 32: 0x01
    UW UART_IER, 0x00

// ---------------- Modem status in loopback (8.8, 8.9) ----------------
// DTR -> DSR, RTS -> CTS, OUT1 -> RI, OUT2 -> DCD.  Deltas are set on any change of DSR, CTS, DCD
// and on RI turning off (TERI), and cleared by reading MSR.
    jal ra, uart_quiesce            // MCR = 0x10, deltas cleared
    UW UART_MCR, 0x11
    CHK UART_MSR                    // 33: 0x22
    CHK UART_MSR                    // 34: 0x20
    UW UART_MCR, 0x13
    CHK UART_MSR                    // 35: 0x31
    CHK UART_MSR                    // 36: 0x30
    UW UART_MCR, 0x17
    CHK UART_MSR                    // 37: 0x70, RI turning on is not TERI
    CHK UART_MSR                    // 38: 0x70
    UW UART_MCR, 0x13
    CHK UART_MSR                    // 39: 0x34, TERI
    CHK UART_MSR                    // 40: 0x30
    UW UART_MCR, 0x1B
    CHK UART_MSR                    // 41: 0xB8
    CHK UART_MSR                    // 42: 0xB0
    UW UART_MCR, 0x10
    CHK UART_MSR                    // 43: 0x0B
    CHK UART_MSR                    // 44: 0x00
// A delta stays set until MSR is read, even if the input changes back.
    UW UART_MCR, 0x12
    UW UART_MCR, 0x10
    CHK UART_MSR                    // 45: 0x01
// The modem status interrupt follows IER[3].
    UW UART_MCR, 0x12
    CHK UART_IIR                    // 46: 0x01
    UW UART_IER, 0x08
    CHK UART_IIR                    // 47: 0x00
    CHK UART_MSR                    // 48: 0x11
    CHK UART_IIR                    // 49: 0x01
    UW UART_IER, 0x00
    UW UART_MCR, 0x10
    UR UART_MSR
// Leaving and entering loopback switches MSR between the modem inputs (CTS asserted by the uncore)
// and MCR.
    UW UART_MCR, 0x00
    CHK UART_MSR                    // 50: 0x11
    CHK UART_MSR                    // 51: 0x10
    UW UART_MCR, 0x10
    CHK UART_MSR                    // 52: 0x01
    CHK UART_MSR                    // 53: 0x00

// ---------------- INTR output (8.7) through the PLIC ----------------
// The UART is PLIC source 10.  INTR is high while IIR reports an interrupt.
    li t3, 0x0C000028
    li t2, 1
    sw t2, 0(t3)                    // UART priority 1
    li t3, 0x0C200000
    sw zero, 0(t3)                  // threshold 0
    li t3, 0x0C002000
    li t2, (1 << UART_IRQ)
    sw t2, 0(t3)                    // enable only the UART for machine mode
    li t3, PLIC_CLAIM0
    lw t2, 0(t3)                    // claim and complete anything pending
    sw t2, 0(t3)
    li t3, PLIC_PENDING0
    lw t2, 0(t3)
    srli t2, t2, UART_IRQ
    andi t2, t2, 1
    SIGR t2                         // 54: 0, no UART interrupt
    UW UART_THR, 0x44               // re-arm THRE
    WAIT_LSR 0x40, 0x40
    UR UART_RBR
    UW UART_IER, 0x02               // THRE interrupt
    li t3, PLIC_PENDING0
    lw t2, 0(t3)
    srli t2, t2, UART_IRQ
    andi t2, t2, 1
    SIGR t2                         // 55: 1
    UW UART_IER, 0x00               // INTR low again
    li t3, PLIC_CLAIM0
    lw t2, 0(t3)
    sw t2, 0(t3)
    SIGR t2                         // 56: 10, claimed the UART
    li t3, PLIC_PENDING0
    lw t2, 0(t3)
    srli t2, t2, UART_IRQ
    andi t2, t2, 1
    SIGR t2                         // 57: 0, not pending again after completion
    li t3, 0x0C002000
    sw zero, 0(t3)
    li t3, 0x0C000028
    sw zero, 0(t3)

    jal ra, uart_quiesce

END_TESTS

UART_HELPERS

TEST_STACK_AND_DATA

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each).  SIG_NEXT in WALLY-TEST-LIB.h checks
//   each entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x06, 0x63, 0x04, 0x22, 0x02, 0x00, 0x11, 0x01     // 0: priority
WORD 0x01, 0x00, 0x02, 0x04, 0x01                       // 8: IER gating
WORD 0x02, 0x01, 0x02, 0x02, 0x01, 0x04, 0x32, 0x02     // 13: THRE
WORD 0xC1, 0xC2, 0xC2                                   // 21: THRE, FIFO mode
WORD 0x06, 0x63, 0x01, 0x06, 0x65, 0x01                 // 24: line status
WORD 0x04, 0x43, 0x01                                   // 30: received data
WORD 0x22, 0x20, 0x31, 0x30, 0x70, 0x70, 0x34, 0x30, 0xB8, 0xB0, 0x0B, 0x00  // 33: MSR
WORD 0x01                                               // 45: delta held
WORD 0x01, 0x00, 0x11, 0x01                             // 46: modem status interrupt
WORD 0x11, 0x10, 0x01, 0x00                             // 50: loopback switch
WORD 0, 1, 10, 0                                        // 54: INTR through the PLIC
WORD 0x0B                                               // 58: ecall from test termination
expected_signature_end:
