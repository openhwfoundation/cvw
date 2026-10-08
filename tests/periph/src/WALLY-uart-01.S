///////////////////////////////////////////
//
// WALLY-uart
//
// Author: David_Harris@hmc.edu and Nicholas Lucio <nlucio@hmc.edu>
//
// Created 2022-06-16
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"


INIT_TESTS

TRAP_HANDLER m

j run_test_loop // begin test loop/table tests instead of executing inline code.

INIT_TEST_TABLE

END_TESTS

TEST_STACK_AND_DATA

.align REGSHIFT

.equ UART, 0x10000000
.equ UART_RBR, (UART)
.equ UART_THR, (UART)
.equ UART_IER, (UART+0x01)
.equ UART_IIR, (UART+0x02)
.equ UART_FCR, (UART+0x02)
.equ UART_LCR, (UART+0x03)
.equ UART_MCR, (UART+0x04)
.equ UART_LSR, (UART+0x05)
.equ UART_MSR, (UART+0x06)
.equ UART_Scr, (UART+0x07)

test_cases:
# ---------------------------------------------------------------------------------------------
# Test Contents
#
#   Here is where the actual tests are held, or rather, what the actual tests do.
#   each entry consists of 3 values that will be read in as follows:
#
#   'WORD [x28 Value], [x29 Value], [x30 value]'
#                     or
#   'WORD [address], [value], [test type]'
#
#   The encoding for x30 test type values can be found in the test handler in the framework file
#
# ---------------------------------------------------------------------------------------------

# =========== UART resets to correct values on master reset ===========

WORD UART_IER, 0x00, read08_test
WORD UART_IIR, 0x01, read08_test # IIR resets to 1
# WORD UART_LCR, 0x00, read08_test *** commented out because LCR should reset to zero but resets to 3 to help Linux boot
WORD UART_MCR, 0x00, read08_test
WORD UART_LSR, 0x60, read08_test # LSR resets with transmit status bits set
WORD UART_MSR, 0x00, read04_test

# =========== Basic read-write ===========

WORD UART_LCR, 0x00, write08_test # set LCR to initial value
WORD UART_MCR, 0x10, write08_test # put UART into loopback for MSR test
WORD UART_LSR, 0x60, read08_test
WORD UART_THR, 0x00, write08_test # write value to UART
WORD UART_LSR, 0x00, read08_test  # data not ready and transmitter is not empty
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and LSR
WORD UART_RBR, 0x00, read08_test  # read written value
WORD UART_LSR, 0x60, read08_test  # read LSR

# =========== Different size read-write ===========

# Transmit 5 bits

WORD UART_LCR, 0x00, write08_test # set LCR to transmit 5 bits
WORD UART_THR, 0x55, write08_test # write value to UART
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and then LSR
WORD UART_RBR, 0x15, read08_test  # read written value without bits 5-7

# Transmit 6 bits

WORD UART_LCR, 0x01, write08_test # set LCR to transmit six bits
WORD UART_THR, 0xAA, write08_test # write value to UART
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and then LSR
WORD UART_RBR, 0x2A, read08_test  # read written value without bits 6 & 7

# Transmit 7 bits

WORD UART_LCR, 0x02, write08_test # set LCR to transmit seven bits
WORD UART_THR, 0xFF, write08_test # write value to UART
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and then LSR
WORD UART_RBR, 0x7F, read08_test  # read written value without bit 7

# Transmit 8 bits

WORD UART_LCR, 0x03, write08_test # set LCR to transmit eight bits
WORD UART_THR, 0x80, write08_test # write value to UART
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and then LSR
WORD UART_RBR, 0x80, read08_test  # read full written value + sign extension

# Check function with odd parity

WORD UART_LCR, 0x0B, write08_test # set LCR to transmit 8 bits + odd partiy
WORD UART_THR, 0x79, write08_test # write value to UART
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and then LSR
WORD UART_RBR, 0x79, read08_test  # read full written value

# Check function with even parity

WORD UART_LCR, 0x1B, write08_test # set LCR to transmit 8 bits + even parity
WORD UART_THR, 0x6A, write08_test # write value to UART
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and then LSR
WORD UART_RBR, 0x6A, read08_test  # read full written value

# Check function with extra stop bit

WORD UART_LCR, 0x07, write08_test # set LCR to transmit 8 bits + extra stop
WORD UART_THR, 0x5B, write08_test # write value to UART
WORD 0x0, 0x0101, uart_data_wait  # wait for data to become ready then output IIR and then LSR
WORD UART_RBR, 0x5B, read08_test  # read full written value
WORD UART_LCR, 0x03, write08_test # set LCR to transmit 8 bits + no extra stop bit

# =========== Transmit-related interrupts ===========

WORD UART_IER, 0x07, write08_test     # enable data available, buffer empty, and line status interrupts
WORD UART_IIR, 0x02, read08_test      # buffer should be empty, causing interrupt
WORD UART_THR, 0x00, write08_test     # write zeroes to transmitter
WORD 0x0, 0x0401, uart_data_wait      # IIR should have data ready interrupt
WORD UART_THR, 0x01, write08_test     # write 1 to transmitter buffer
WORD UART_IIR, 0x04, read08_test      # data interrupt should still be high
WORD 0x0, 0x06, uart_lsr_intr_wait    # wait for transmission to complete, IIR should throw error due to overrun error.
WORD UART_LSR, 0x23, read08_test      # read overrun error from LSR
WORD UART_IIR, 0x04, read08_test      # check that LSR interrupt was cleared
WORD UART_RBR, 0x01, read08_test      # read previous value from UART

# =========== MODEM interrupts ===========

WORD UART_MSR, 0x00, write08_test # clear MSR
WORD UART_IER, 0x08, write08_test # enable MODEM Status interrupts
WORD UART_IIR, 0x01, read08_test  # no interrupts pending
WORD UART_MCR, 0x12, write08_test # Cause DCTS interrupt
WORD UART_IIR, 0x00, read08_test  # MODEM interrupt
WORD UART_MSR, 0x11, read08_test  # Read MSR to clear interrupt
WORD UART_IIR, 0x01, read08_test  # interrupt cleared by reading MSR
WORD UART_MCR, 0x13, write08_test # Set DSR high
WORD UART_IIR, 0x00, read08_test  # MODEM interrupt
WORD UART_MSR, 0x32, read08_test  # Read MSR to clear interrupt
WORD UART_IIR, 0x01, read08_test  # Interrupt cleared by reading MSR
WORD UART_MCR, 0x17, write08_test # Set RIb low and keep CTS and DSR
WORD UART_MCR, 0x13, write08_test # Set RIb high and keep CTS and DSR
WORD UART_IIR, 0x00, read08_test  # MODEM interrupt
WORD UART_MSR, 0x34, read08_test  # Read MSR to clear interrupt
WORD UART_IIR, 0x01, read08_test  # Interrupt cleared by reading MSR
WORD UART_MCR, 0x1B, write08_test # Set DCD high and keep CTS and DSR
WORD UART_IIR, 0x00, read08_test  # MODEM interrupt
WORD UART_MSR, 0xb8, read08_test  # Read MSR to clear interrupt
WORD UART_IIR, 0x01, read08_test  # Interrupt cleared by reading MSR
WORD UART_MCR, 0x10, write08_test # Clear MCR
WORD UART_MSR, 0x00, write08_test # Clear MSR

# =========== FIFO interrupts ===========

WORD UART_IER, 0x07, write08_test # enable data available, buffer empty, and line status interrupts
WORD UART_FCR, 0x41, write08_test # Set FIFO threshold to 4 and enable FIFO mode
WORD UART_IIR, 0xC2, read08_test  # Enabling FIFO sets top two bits of IIR
WORD UART_THR, 0x00, write08_test # write 0 to transmit register
WORD 0x0, 0xC101, uart_data_wait  # no interrupts pending (transmitter interrupt squashed by early read)
WORD UART_RBR, 0x00, read08_test  # read 0 from buffer register
WORD UART_THR, 0xA5, write08_test # Write A5 to transmit register
WORD UART_THR, 0x01, write08_test # Write 1 to transmit register
WORD UART_IIR, 0xC1, read08_test  # no interrupts pending
WORD UART_THR, 0x02, write08_test # Write 2 to transmit register
WORD UART_THR, 0x03, write08_test # Write 3 to transmit register
WORD 0x0, 0xC401, uart_data_wait  # Interrupt due to data ready
WORD UART_RBR, 0xA5, read08_test  # Read A5 from buffer register
WORD UART_IIR, 0xC2, read08_test   # Data ready interrupt cleared
WORD UART_RBR, 0x01, read08_test  # Read 1 from buffer register
WORD UART_RBR, 0x02, read08_test  # Read 2 from buffer register
WORD UART_LSR, 0x61, read08_test  # Data ready, 1 item left in FIFO
WORD UART_RBR, 0x03, read08_test  # Read 3 from buffer register
WORD UART_LSR, 0x60, read08_test  # No data ready, FIFO is empty
WORD UART_THR, 0xFF, write08_test # Write FF to transmit register
WORD UART_THR, 0xFE, write08_test # Write FE to transmit register
WORD 0x0, 0xC101, uart_data_wait  # Interrupt due to data ready
WORD UART_FCR, 0xC7, write08_test # Clear all bytes in FIFO
WORD UART_FCR, 0xC1, read08_test  # Check that FCR clears bits 1 and 2 when written to 1
WORD UART_LSR, 0x60, read08_test  # No data ready, FIFO cleared by writing to FCR

# =========== FIFO receiver/overrun ===========

WORD UART_FCR, 0x01, write08_test # Set FIFO trigger threshold to 1 and enable FIFO mode
WORD UART_IIR, 0xC1, read08_test  # FIFO has not reached trigger level
WORD UART_THR, 0x00, write08_test # Write 0 to transmit register
WORD 0x0, 0xC401, uart_data_wait  # Interrupt due to trigger threshold reached
WORD UART_FCR, 0x41, write08_test # Set FIFO trigger threshold to 4
WORD UART_IIR, 0xC1, read08_test  # FIFO has not reached trigger threshold
WORD UART_THR, 0x01, write08_test # Write 1 to transmit register
WORD UART_THR, 0x02, write08_test # Write 2 to transmit register
WORD 0x0, 0xC101, uart_data_wait  # FIFO has not reached trigger threshold
WORD UART_THR, 0x03, write08_test # Write 3 to transmit register
WORD 0x0, 0xC401, uart_data_wait  # Interrupt due to trigger threshold reached
WORD UART_FCR, 0x81, write08_test # Set FIFO trigger threshold to 8
WORD UART_IIR, 0xC1, read08_test  # FIFO has not reached trigger threshold
WORD UART_THR, 0x04, write08_test # Write 4 to transmit register
WORD UART_THR, 0x05, write08_test # Write 5 to transmit register
WORD UART_THR, 0x06, write08_test # Write 6 to transmit register
WORD 0x0, 0xC101, uart_data_wait  # FIFO has not reached trigger threshold
WORD UART_THR, 0x07, write08_test # Write 7 to transmit register
WORD 0x0, 0xC401, uart_data_wait  # Interrupt due to trigger threshold reached
WORD UART_FCR, 0xC1, write08_test # Set FIFO trigger threshold to 14
WORD UART_IIR, 0xC1, read08_test  # FIFO has not reached trigger threshold
WORD UART_THR, 0x08, write08_test # Write 8 to transmit register
WORD UART_THR, 0x09, write08_test # Write 9 to transmit register
WORD UART_THR, 0x0A, write08_test # Write 10 to transmit register
WORD UART_THR, 0x0B, write08_test # Write 11 to transmit register
WORD UART_THR, 0x0C, write08_test # Write 12 to transmit register
WORD 0x0, 0xC101, uart_data_wait  # FIFO has not reached trigger threshold
WORD UART_THR, 0x0D, write08_test # Write 13 to transmit register
WORD 0x0, 0xC401, uart_data_wait  # Interrupt due to trigger threshold reached
WORD UART_THR, 0x0E, write08_test # Write 14 to transmit register
WORD UART_THR, 0x0F, write08_test # Write 15 to transmit register
WORD 0x0, 0xC101, uart_data_wait
WORD UART_LSR, 0x61, read08_test      # FIFO contains data, no overrun error
WORD UART_THR, 0x10, write08_test     # Write 16 to transmit register, filling RX shift register
WORD UART_THR, 0x11, write08_test     # Write 17 to transmit register, destroying contents held in shift register
WORD 0x0, 0x06, uart_lsr_intr_wait    # Wait for LSR interrupt ID
WORD UART_LSR, 0xA3, read08_test      # Read overrun error from LSR

WORD 0x0, 0x0, terminate_test

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each; SEXT32 marks values that are sign extended on RV64).  SIG_NEXT in WALLY-TEST-LIB.h checks each
//   entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x00000000 // 0: Reset tests
WORD 0x00000001 // 1: 00000000 *** commented because LCR should reset to zero but resets to 3 due to the FPGA
WORD 0x00000000 // 2
WORD 0x00000060 // 3
WORD 0x00000000 // 4
WORD 0x00000060 // 5: read-write test
WORD 0x00000020 // 6: transmitter register empty but shift register not
WORD 0x00000101 // 7: transmitter is not empty when done transmitting 5 bits
WORD 0x00000000 // 8
WORD 0x00000060 // 9
WORD 0x00000101 // 10: Multi-bit transmission: 5 bits
WORD 0x00000015 // 11
WORD 0x00000101 // 12: Transmit 6 bits
WORD 0x0000002A // 13
WORD 0x00000101 // 14: Transmit 7 bits
WORD 0x0000007F // 15
WORD 0x00000101 // 16: Transmit 8 bits
WORD SEXT32(0xFFFFFF80) // 17
WORD 0x00000101 // 18: Odd parity
WORD 0x00000079 // 19
WORD 0x00000101 // 20: Even parity
WORD 0x0000006A // 21
WORD 0x00000101 // 22: Extra stop bit
WORD 0x0000005B // 23
WORD 0x00000002 // 24: Transmission interrupt tests
WORD 0x00000401 // 25: Interrupt generated by finished transmission
WORD 0x00000004 // 26
WORD 0x00000006 // 27: IIR return LSR intr and LSR has an overflow error
WORD 0x00000063 // 28
WORD 0x00000004 // 29
WORD 0x00000001 // 30
WORD 0x00000001 // 31: MODEM interrupt tests
WORD 0x00000000 // 32
WORD 0x00000011 // 33
WORD 0x00000001 // 34
WORD 0x00000000 // 35: DSR Test
WORD 0x00000032 // 36
WORD 0x00000001 // 37
WORD 0x00000000 // 38: RI Test
WORD 0x00000034 // 39
WORD 0x00000001 // 40
WORD 0x00000000 // 41: DCD Test
WORD SEXT32(0xFFFFFFB8) // 42
WORD 0x00000001 // 43
WORD SEXT32(0xFFFFFFC2) // 44: FIFO interrupt
WORD 0x0000C101 // 45
WORD 0x00000000 // 46
WORD SEXT32(0xFFFFFFC1) // 47
WORD 0x0000C401 // 48
WORD SEXT32(0xFFFFFFA5) // 49
WORD SEXT32(0xFFFFFFC1) // 50
WORD 0x00000001 // 51
WORD 0x00000002 // 52
WORD 0x00000061 // 53
WORD 0x00000003 // 54
WORD 0x00000060 // 55
WORD 0x0000C101 // 56
WORD SEXT32(0xFFFFFFC1) // 57
WORD 0x00000060 // 58
WORD SEXT32(0xFFFFFFC1) // 59: FIFO filling/overrun test
WORD 0x0000C401 // 60: Threshold = 1
WORD SEXT32(0xFFFFFFC1) // 61: Threshold = 4
WORD 0x0000C101 // 62
WORD 0x0000C401 // 63
WORD SEXT32(0xFFFFFFC1) // 64: Threshold = 8
WORD 0x0000C101 // 65
WORD 0x0000C401 // 66
WORD SEXT32(0xFFFFFFC1) // 67: Threshold = 14
WORD 0x0000C101 // 68
WORD 0x0000C401 // 69
WORD 0x0000C101 // 70
WORD 0x00000061 // 71: FIFO has data, no overrun
WORD 0x00000006 // 72: wait for interrupt
WORD SEXT32(0xFFFFFFA3) // 73: FIFO overrun error
WORD 0x0000000B // 74: ecall from test termination
expected_signature_end:
