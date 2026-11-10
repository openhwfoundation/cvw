///////////////////////////////////////////
// uartLSRerr.S
//
// Written David_Harris@hmc.edu 10/14/26
//
// Purpose: UART receiver error status in FIFO mode.  LSR[7] (error in receiver FIFO) must be set while a
//          character with a parity error is in the receive FIFO and must clear on an LSR read once none is
//          left.  The parity, framing and break bits of LSR must describe the characters received since
//          the last LSR read, so a clean character arriving after an LSR read reports no error.  A
//          character arriving when the receive FIFO is full is lost with an overrun error, and the FIFO
//          keeps the characters it holds.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

.equ UART,     0x10000000
.equ UART_RBR, 0            // offsets from UART
.equ UART_THR, 0
.equ UART_IER, 1
.equ UART_FCR, 2
.equ UART_LCR, 3
.equ UART_MCR, 4
.equ UART_LSR, 5

// Loopback cannot corrupt a character on the wire, so a parity error is made by transmitting with even
// parity and switching the receiver to odd parity while the character is in flight.
.equ LCR_8N1,  0x03
.equ LCR_8E1,  0x1B
.equ LCR_8O1,  0x0B

// WAITCHAR: wait long enough for one character to cross the loopback at the reset divisor
.macro WAITCHAR
    rdcycle t2
    li t3, 20000
    add t2, t2, t3
1:  rdcycle t3
    bltu t3, t2, 1b
.endm

// CHECKREG offset, expected, index: read a UART register and check its value
.macro CHECKREG offset, expected, index
    lbu a1, \offset(s0)
    li a2, \expected
    SC_CHECK_EQ a1, a2, \index
.endm

// SEND lcrtx, lcrrx, data: transmit data with line control lcrtx, then switch to lcrrx for the receiver
.macro SEND lcrtx, lcrrx, data
    li a1, \lcrtx
    sb a1, UART_LCR(s0)
    li a1, \data
    sb a1, UART_THR(s0)
    li a1, \lcrrx
    sb a1, UART_LCR(s0)
    WAITCHAR
.endm

main:
    li s0, UART
    li a1, LCR_8N1
    sb a1, UART_LCR(s0)         // 8 data bits, no parity, DLAB = 0
    li a1, 0x10
    sb a1, UART_MCR(s0)         // loopback
    sb zero, UART_IER(s0)       // no interrupts
    li a1, 0x07
    sb a1, UART_FCR(s0)         // enable the FIFOs and reset them, receive trigger level 1
    CHECKREG UART_LSR, 0x60, 0  // idle: THRE and TEMT

    // One character with a parity error
    SEND LCR_8E1, LCR_8O1, 0x6A
    CHECKREG UART_LSR, 0xE5, 1  // error in FIFO, THRE, TEMT, parity error, data ready
    CHECKREG UART_RBR, 0x6A, 2
    CHECKREG UART_LSR, 0xE0, 3  // FIFO empty; LSR[7] was set before this read, which clears it
    CHECKREG UART_LSR, 0x60, 4

    // A clean character afterwards reports no error
    SEND LCR_8O1, LCR_8O1, 0x55
    CHECKREG UART_LSR, 0x61, 5
    CHECKREG UART_RBR, 0x55, 6
    CHECKREG UART_LSR, 0x60, 7

    // An error character behind a clean one: LSR[7] stays set until the error character is read
    SEND LCR_8O1, LCR_8O1, 0x33
    SEND LCR_8E1, LCR_8O1, 0x0F
    CHECKREG UART_LSR, 0xE5, 8
    CHECKREG UART_RBR, 0x33, 9
    CHECKREG UART_LSR, 0xE1, 10 // error character still in the FIFO
    CHECKREG UART_RBR, 0x0F, 11
    CHECKREG UART_LSR, 0xE0, 12
    CHECKREG UART_LSR, 0x60, 13

    // An error character read before the LSR: LSR[7] is still reported once, then clears
    SEND LCR_8E1, LCR_8O1, 0x5A
    CHECKREG UART_RBR, 0x5A, 14
    CHECKREG UART_LSR, 0xE4, 15 // parity error of the character just read
    CHECKREG UART_LSR, 0x60, 16

    // Overrun: the receive FIFO holds 15 characters; a 16th is lost and sets the overrun error
    li a1, LCR_8N1
    sb a1, UART_LCR(s0)
    li a1, 0x07
    sb a1, UART_FCR(s0)         // reset both FIFOs
    li a1, 0x40                 // transmit 0x40-0x4E, which fill the receive FIFO
    li a2, 0x4F
1:  sb a1, UART_THR(s0)
    addi a1, a1, 1
    bne a1, a2, 1b
    WAITCHAR
    WAITCHAR
    sb a2, UART_THR(s0)         // 0x4F overruns the full FIFO
    WAITCHAR
    CHECKREG UART_LSR, 0x63, 17 // THRE, TEMT, overrun, data ready
    li a3, 0x40                 // the FIFO still holds 0x40-0x4E in order
    li a4, 0x4F
2:  lbu a1, UART_RBR(s0)
    SC_CHECK_EQ a1, a3, 18
    addi a3, a3, 1
    bne a3, a4, 2b
    CHECKREG UART_LSR, 0x60, 19 // empty, overrun cleared by the LSR read above

    sb zero, UART_MCR(s0)       // leave loopback
    j done
