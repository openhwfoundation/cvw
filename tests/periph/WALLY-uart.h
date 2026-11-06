///////////////////////////////////////////
// WALLY-uart.h
//
// Purpose: UART register map, signature macros, and helper routines shared by the WALLY-uart-*
//          peripheral tests.  The expected values in those tests follow the PC16550D datasheet
//          (National Semiconductor, "PC16550D Universal Asynchronous Receiver/Transmitter with
//          FIFOs", June 1995), cited by section, rather than the current RTL.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// The UART tests run with machine interrupts disabled and poll the UART (and the PLIC pending bits).
// Characters travel through the internal loopback (MCR[4]), because the testbench ties SIN high.
// The uncore ties the modem inputs to CTSb = 0 (CTS asserted), DSRb = DCDb = RIb = 1.
//
// Register use (besides those the test library reserves: t1, a6, s9-s11, sp, tp):
//   s0     UART base address
//   s1     cycles of one 8N1 character (10 bits) at the current divisor, from uart_calibrate
//   s2-s8  free for the tests; preserved by the helpers
//   a0-a5, t0, t2-t6, ra: arguments and scratch, clobbered by the helpers

.equ UART,      0x10000000
.equ UART_RBR,  0      // receiver buffer (read, DLAB = 0)
.equ UART_THR,  0      // transmitter holding (write, DLAB = 0)
.equ UART_DLL,  0      // divisor latch LS (DLAB = 1)
.equ UART_IER,  1      // interrupt enable (DLAB = 0)
.equ UART_DLM,  1      // divisor latch MS (DLAB = 1)
.equ UART_IIR,  2      // interrupt identification (read)
.equ UART_FCR,  2      // FIFO control (write)
.equ UART_LCR,  3
.equ UART_MCR,  4
.equ UART_LSR,  5
.equ UART_MSR,  6
.equ UART_SCR,  7

.equ PLIC_PENDING0, 0x0C001000  // interrupt pending bits of sources 31:0
.equ PLIC_CLAIM0,   0x0C200004  // machine-mode claim/complete
.equ UART_IRQ,      10          // UART interrupt source number

// Append register \reg to the signature and check it.
.macro SIGR reg
    SREG \reg, 0(t1)
    SIG_NEXT
.endm

// Append a constant to the signature (a summary such as a count of errors).
.macro SIGI val
    li t2, \val
    SIGR t2
.endm

// Write constant \val to UART register \off.
.macro UW off, val
    li t2, \val
    sb t2, \off(s0)
.endm

// Read UART register \off (zero extended) into t2.
.macro UR off
    lbu t2, \off(s0)
.endm

// Read UART register \off into the signature.
.macro CHK off
    lbu t2, \off(s0)
    SIGR t2
.endm

// Read UART register \off, keep the bits in \mask, and append the result to the signature.
.macro CHKM off, mask
    lbu t2, \off(s0)
    andi t2, t2, \mask
    SIGR t2
.endm

// Wait until (LSR & \mask) == \val; a0 = LSR, or 0xBAD if the wait timed out.
.macro WAIT_LSR mask, val
    li a0, \mask
    li a1, \val
    jal ra, uart_wait_lsr
.endm

// Wait \n half characters (8N1 at the current divisor, from s1).
.macro WAIT_HALF_CHARS n
    li a0, \n
    jal ra, uart_wait_half_chars
.endm

// Execute exactly \reg nops (0 <= \reg < 1024).
.macro NOPS reg
    mv a0, \reg
    jal ra, uart_nops
.endm

// Helper routines.  Place UART_HELPERS once in each test, after END_TESTS.
.macro UART_HELPERS

// uart_wait_lsr: poll until (LSR & a0) == a1.  Returns a0 = LSR value, or 0xBAD after about 400000
// polls (several times the longest character any test sends).  Uses t2-t4.
uart_wait_lsr:
    li t4, 400000
1:
    lbu t2, UART_LSR(s0)
    and t3, t2, a0
    beq t3, a1, 2f
    addi t4, t4, -1
    bnez t4, 1b
    li a0, 0xBAD
    ret
2:
    mv a0, t2
    ret

// uart_delay: wait a0 cycles (mcycle).  Uses t2, t3.
uart_delay:
    csrr t2, mcycle
1:
    csrr t3, mcycle
    sub t3, t3, t2
    bltu t3, a0, 1b
    ret

// uart_wait_half_chars: wait a0 half characters (s1/2 cycles each).  Uses a0, t2-t4.
uart_wait_half_chars:
    srli t4, s1, 1
    li t3, 0
1:
    beqz a0, 2f
    add t3, t3, t4
    addi a0, a0, -1
    j 1b
2:
    mv a0, t3
    j uart_delay

// uart_nops: execute exactly a0 nops (0 <= a0 < 1024) by jumping into a nop sled.  Uses t2, t3.
uart_nops:
    la t2, uart_nop_sled_end
    slli t3, a0, 2
    sub t2, t2, t3
    jr t2
uart_nop_sled:
    .rept 1024
    nop
    .endr
uart_nop_sled_end:
    ret

// uart_set_divisor: set the divisor latch to a0 and LCR to 8N1.  Uses t2.
uart_set_divisor:
    li t2, 0x83
    sb t2, UART_LCR(s0)
    sb a0, UART_DLL(s0)
    srli t2, a0, 8
    sb t2, UART_DLM(s0)
    li t2, 0x03
    sb t2, UART_LCR(s0)
    ret

// uart_frame_cycles: transmit a0 (the transmitter must be idle) and return a0 = cycles from the THR
// write until TEMT is set again, or 0xBAD on a timeout.  The character is received in loopback and left
// for the caller.  Uses a0-a2, t2-t5, ra (saved in a2).
uart_frame_cycles:
    mv a2, ra
    csrr t5, mcycle
    sb a0, UART_THR(s0)
    WAIT_LSR 0x40, 0x00            // the transmitter has started
    li t2, 0xBAD
    beq a0, t2, 1f
    WAIT_LSR 0x40, 0x40            // and finished
    li t2, 0xBAD
    beq a0, t2, 1f
    csrr t2, mcycle
    sub a0, t2, t5
1:
    mv ra, a2
    ret

// uart_calibrate: s1 = cycles of one 8N1 character at the current divisor.  Needs loopback, the
// transmitter idle, and FIFOs off; discards the received character.  Uses a0-a2, t2-t5.
uart_calibrate:
    mv s1, ra
    li a0, 0x55
    jal ra, uart_frame_cycles
    mv ra, s1
    mv s1, a0
    lbu t2, UART_RBR(s0)          // discard the character
    ret

// uart_quiesce: return the UART to a known state between sections: interrupts disabled, 8N1,
// loopback with the modem outputs off, FIFOs disabled and empty, no pending flags.  Waits for the
// transmitter and any character still arriving.  Uses a0-a2, t2-t4, ra (saved in a3).
uart_quiesce:
    mv a3, ra
    li t2, 0x00
    sb t2, UART_IER(s0)
    li t2, 0x03
    sb t2, UART_LCR(s0)
    li t2, 0x10
    sb t2, UART_MCR(s0)
    WAIT_LSR 0x40, 0x40
    li a0, 4
    jal ra, uart_wait_half_chars    // let a character still in the receiver finish
    li t2, 0x07
    sb t2, UART_FCR(s0)             // reset both FIFOs
    li t2, 0x00
    sb t2, UART_FCR(s0)             // and disable them
    lbu t2, UART_RBR(s0)
    lbu t2, UART_LSR(s0)
    lbu t2, UART_MSR(s0)
    lbu t2, UART_IIR(s0)
    mv ra, a3
    ret

// uart_settle: wait for the transmitter to finish, then two more characters so that the receiver is
// idle (and a break has ended).  Returns a0 = LSR.  Uses a0-a1, a3, t2-t4.
uart_settle:
    mv a3, ra
    WAIT_LSR 0x40, 0x40
    li a0, 4
    jal ra, uart_wait_half_chars
    lbu a0, UART_LSR(s0)
    mv ra, a3
    ret

// uart_xfer_switch: transmit a0 with LCR = a1, and once the character has started, set LCR = a2 so
// that the receiver checks it with a different format.  The transmitter computes the parity bit and
// frame when it loads the shift register; the receiver checks them as the character completes.
// Returns a0 = LSR when data ready is seen (0xBAD on a timeout) and a1 = RBR, then waits for the
// transmitter to finish.  Leaves LCR = a2.  Uses a0-a5, t2-t4.
uart_xfer_switch:
    mv a5, ra
    mv a4, a2
    sb a1, UART_LCR(s0)
    sb a0, UART_THR(s0)
    WAIT_LSR 0x40, 0x00            // the character is in the transmit shift register
    sb a4, UART_LCR(s0)
    WAIT_LSR 0x01, 0x01
    mv a3, a0                       // LSR with the character's status
    lbu a4, UART_RBR(s0)
    WAIT_LSR 0x40, 0x40
    mv a0, a3
    mv a1, a4
    mv ra, a5
    ret

// uart_send_switch: like uart_xfer_switch, but leaves the received character in the receiver (no
// RBR read): transmit a0 with LCR = a1, set LCR = a2 once it has started, and wait for TEMT.
// Uses a0-a1, a4-a5, t2-t4.
uart_send_switch:
    mv a5, ra
    mv a4, a2
    sb a1, UART_LCR(s0)
    sb a0, UART_THR(s0)
    WAIT_LSR 0x40, 0x00
    sb a4, UART_LCR(s0)
    WAIT_LSR 0x40, 0x40
    mv ra, a5
    ret

// uart_send_switch_timed: like uart_send_switch, but after the LCR change it waits 1.5 8N1 characters
// by the cycle counter instead of polling LSR, because an LSR read after the character arrives
// would consume its error flags.  Uses a0-a1, a4-a5, t2-t4.
uart_send_switch_timed:
    mv a5, ra
    mv a4, a2
    sb a1, UART_LCR(s0)
    sb a0, UART_THR(s0)
    WAIT_LSR 0x40, 0x00
    sb a4, UART_LCR(s0)
    li a0, 3
    jal ra, uart_wait_half_chars
    mv ra, a5
    ret

// uart_div: a0 = floor(a0 / a1) by repeated subtraction (small quotients only).  Uses t2.
uart_div:
    li t2, 0
1:
    bltu a0, a1, 2f
    sub a0, a0, a1
    addi t2, t2, 1
    j 1b
2:
    mv a0, t2
    ret
.endm
