///////////////////////////////////////////
// WALLY-uart-regs-01.S
//
// Purpose: UART register file: reset values, read/write masks, the divisor latch access bit, IIR FIFO
//          bits, and the modem status bits that the register writes cause.  No characters are sent.
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

// ---------------- Reset values (Table I) ----------------
    CHK UART_IER                    // 0: 0x00
    CHK UART_IIR                    // 1: 0x01, no interrupt pending, FIFOs disabled
    CHK UART_LCR                    // 2: 0x03; the datasheet resets LCR to 0, Wally resets it to 8N1 on purpose
    CHK UART_MCR                    // 3: 0x00
    CHK UART_LSR                    // 4: 0x60, THRE and TEMT
    CHK UART_MSR                    // 5: 0x10, CTS asserted by the uncore tie-off, no deltas

// ---------------- Scratch register (8.10): all 8 bits ----------------
    UW UART_SCR, 0xA5
    CHK UART_SCR                    // 6
    UW UART_SCR, 0x5A
    CHK UART_SCR                    // 7
    UW UART_SCR, 0xFF
    CHK UART_SCR                    // 8
    UW UART_SCR, 0x00
    CHK UART_SCR                    // 9

// ---------------- LCR (8.1): all 8 bits read back ----------------
    UW UART_LCR, 0x5C
    CHK UART_LCR                    // 10
    UW UART_LCR, 0xA3
    CHK UART_LCR                    // 11
    UW UART_LCR, 0x03
    CHK UART_LCR                    // 12

// ---------------- IER (8.7): bits 7:4 are always 0 ----------------
    UW UART_IER, 0xFF
    CHK UART_IER                    // 13: 0x0F
    UW UART_IER, 0x00
    CHK UART_IER                    // 14

// ---------------- MCR (8.8): bits 7:5 are always 0; MSR follows the loopback (8.9) ----------------
    UW UART_MCR, 0xFF
    CHK UART_MCR                    // 15: 0x1F
    // loopback with DTR, RTS, OUT1, OUT2 on: DSR and DCD rise (deltas), CTS stays 1, RI rises (no TERI)
    CHK UART_MSR                    // 16: 0xFA
    CHK UART_MSR                    // 17: 0xF0, deltas cleared by the read
    UW UART_MCR, 0x00
    CHK UART_MCR                    // 18
    // back to the tie-offs: DSR and DCD fall (deltas), RI falls (trailing edge), CTS stays 1
    CHK UART_MSR                    // 19: 0x1E
    CHK UART_MSR                    // 20: 0x10

// ---------------- Divisor latch access (8.3, Table II) ----------------
    UW UART_IER, 0x05
    UW UART_LCR, 0x83
    UW UART_DLL, 0x5A
    UW UART_DLM, 0xA5
    CHK UART_DLL                    // 21: 0x5A
    CHK UART_DLM                    // 22: 0xA5, not IER
    CHK UART_LCR                    // 23: 0x83
    UW UART_FCR, 0x01               // FCR and IIR are at address 2 whatever DLAB is
    CHK UART_IIR                    // 24: 0xC1, FIFOs enabled, nothing pending
    UW UART_LCR, 0x03
    CHK UART_IER                    // 25: 0x05, unchanged by the DLM write
    CHK UART_IIR                    // 26: 0xC1
    // with DLAB = 1, a write to address 0 loads DLL and does not transmit
    UW UART_LCR, 0x83
    UW UART_DLL, 0x01
    UW UART_DLM, 0x00
    UW UART_LCR, 0x03
    CHK UART_LSR                    // 27: 0x60, the transmitter is still empty
    UW UART_FCR, 0x00
    CHK UART_IIR                    // 28: 0x01
    UW UART_IER, 0x00

// ---------------- IIR FIFO bits (8.6): IIR[7:6] = FCR[0], IIR[5:4] = 0 ----------------
    UW UART_FCR, 0xC9
    CHK UART_IIR                    // 29: 0xC1
    UW UART_FCR, 0x00
    CHK UART_IIR                    // 30: 0x01
    UW UART_FCR, 0xC8               // FCR[0] = 0: FIFOs stay disabled
    CHK UART_IIR                    // 31: 0x01

// ---------------- Registers hold their values independently ----------------
    UW UART_SCR, 0x3C
    UW UART_LCR, 0x1B
    UW UART_IER, 0x0A
    UW UART_MCR, 0x15               // loopback, DTR and OUT1
    CHK UART_SCR                    // 32: 0x3C
    CHK UART_LCR                    // 33: 0x1B
    CHK UART_IER                    // 34: 0x0A
    CHK UART_MCR                    // 35: 0x15
    // THRE (enabled) outranks the modem status interrupt (Table IV)
    CHK UART_IIR                    // 36: 0x02
    // reading IIR while it reports THRE clears THRE; the modem status interrupt remains
    CHK UART_IIR                    // 37: 0x00
    // DSR rose and CTS fell (deltas), RI rose (no TERI): DSR and RI on
    CHK UART_MSR                    // 38: 0x63
    CHK UART_IIR                    // 39: 0x01
    UW UART_IER, 0x00
    UW UART_LCR, 0x03
    UW UART_MCR, 0x00

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
WORD 0x00 // 0
WORD 0x01 // 1
WORD 0x03 // 2
WORD 0x00 // 3
WORD 0x60 // 4
WORD 0x10 // 5
WORD 0xA5 // 6
WORD 0x5A // 7
WORD 0xFF // 8
WORD 0x00 // 9
WORD 0x5C // 10
WORD 0xA3 // 11
WORD 0x03 // 12
WORD 0x0F // 13
WORD 0x00 // 14
WORD 0x1F // 15
WORD 0xFA // 16
WORD 0xF0 // 17
WORD 0x00 // 18
WORD 0x1E // 19
WORD 0x10 // 20
WORD 0x5A // 21
WORD 0xA5 // 22
WORD 0x83 // 23
WORD 0xC1 // 24
WORD 0x05 // 25
WORD 0xC1 // 26
WORD 0x60 // 27
WORD 0x01 // 28
WORD 0xC1 // 29
WORD 0x01 // 30
WORD 0x01 // 31
WORD 0x3C // 32
WORD 0x1B // 33
WORD 0x0A // 34
WORD 0x15 // 35
WORD 0x02 // 36
WORD 0x00 // 37
WORD 0x63 // 38
WORD 0x01 // 39
WORD 0x0B // 40: ecall from test termination
expected_signature_end:
