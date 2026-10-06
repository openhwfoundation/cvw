///////////////////////////////////////////
//
// WALLY-uart-timeout
//
// Author: Kip Macsai-Goren <kmacsaigoren@hmc.edu>
//
// Created 2022-10-24
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

INIT_TESTS

TRAP_HANDLER m

WRITE08 UART_IER, 0x07 // enable data available, buffer empty, and line status interrupts
WRITE08 UART_FCR, 0x81 // Set FIFO threshold to 8 and enable FIFO mode
WRITE08 UART_LCR, 0x03 // set word transmit length to be 8 bits

WRITE08 UART_THR, 0xA5 // write A5 to transmit register
WRITE08 UART_THR, 0xA6 // write A6 to transmit register

// since only 2/8 words have been written to the register, we should wait for a long time and get an interrupt

li t2, 0x1000 // counter variable

wait_for_timeout_loop:
    li t3, UART_IIR
    lb t4, 0(t3) // load the value out of interrupt ID register
    li t3, 0xCC // value for FIFO enabled and character timeout interrupt pending
    beq t3, t4, interrupt_success // If that interrupt is pending, we have succeeded in timing out
    // *** won't the processor also try to actually handle the interrupt?
    //      Should I just let that happen? or is this a better option
    addi t2, t2, -1
    beqz t2, no_interrupt // at the end of the loop with not interrupts means this test failed.
    j wait_for_timeout_loop // continue loop

no_interrupt:
    li t2, 0xbad // interrupt not taken. write bad value to the output
    sw t2, 0(t1)
    SIG_NEXT
    j end_of_section

interrupt_success:
    li t2, 0x600d // interrupt successfully taken after some time. write good value to the output.
    sw t2, 0(t1)
    SIG_NEXT
    j end_of_section

end_of_section: // end of this test

END_TESTS

TEST_STACK_AND_DATA

        // in your isa
        // first claim the plic's uart interrupt by reading the claim register corresponding to 10 on context 0.
        // then you'll read all entries in the fifo.
        // then you'll write the completed plic register to 10 on context 0.
        // claim and completed have the same address.
        // then you'll return by mret.

# trap_handler:
#         // this will only get uart interrupts
#         //li s0, plicBaseAddr
#         addi s0, s0, 0x200004 // claim offset
#         lw s1, 0(s0)

#         // check that s1 is 10 and not something else
#         // read uart rx fifo


#         // completed
#         sw s1, 0(s0) // tells the plic the isr is done.
#         mret

// ---------------------------------------------------------------------------------------------
// Expected signature
//
//   One entry per signature write, in order (XLEN bits each; SEXT32 marks values that are sign extended on RV64).  SIG_NEXT in WALLY-TEST-LIB.h checks each
//   entry as soon as it is written; a mismatch halts the test and reports the entry index below.
// ---------------------------------------------------------------------------------------------

.align REGSHIFT
expected_signature:
WORD 0x0000600D // 0: good value indicating the interrupt was correctly taken
expected_signature_end:
