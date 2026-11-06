///////////////////////////////////////////
// WALLY-spi-timing-01.S
//
// Purpose: SPI chip-select behavior that software can see through timing (FE310-G002 19.8, 19.9).
//          With a long cssck (16 SCK periods), a frame that has to assert CS takes at least
//          cssck * T longer from the txdata write to its arrival in the receive FIFO than a frame sent
//          while CS is held.  So the latency shows whether CS was deasserted in between:
//            - HOLD keeps CS asserted after a frame: the next frame has no cssck delay.
//            - In HOLD, CS is deasserted when a different value is written to csmode or csid, or a
//              csdef write changes the selected pin's default; the next frame asserts CS again and
//              waits cssck.  Writing the same value changes nothing.
//            - A switch from OFF to HOLD does not assert CS before the next frame.
//            - csmode written to AUTO and back to HOLD while a frame is in flight deasserts CS after
//              that frame, so the following frame waits cssck again.
//          Each check compares the measured latency against a threshold halfway between the two
//          outcomes (1024 cycles from each), so it does not depend on exact cycle counts.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-TEST-LIB.h"
#include "WALLY-spi.h"

// sckdiv = 63: half period H = 64 cycles, T = 128.  A frame is 16 H = 1024 cycles; cssck = 16 T = 2048.
// Write-to-arrival latency: about 1024-1300 cycles with CS held, at least 3072 with a CS assertion.
.equ DIV, 63
.equ THRESH, 2048                   // 16 H + cssck * T / 2

// Send frame \b and record whether its latency was long (1: CS was asserted for it, with cssck) and
// the frame received.
.macro LAT b, long
    li a0, \b
    jal ra, spi_latency
    li t3, THRESH
    sltu t2, t3, a0
    SIGRE t2, \long
    SIGRE a1, \b
.endm

INIT_TESTS

TRAP_HANDLER m

EXPECT_BEGIN

    li s0, SPI
    SPIW SPI_SCKDIV, DIV
    SPIW SPI_DELAY0, 0x00010010     // cssck = 16, sckcs = 1
    SPIW SPI_DELAY1, 0x00000001     // intercs = 1, interxfr = 0
    SPIW SPI_RXMARK, 0

// ---------------- AUTO: every frame asserts CS ----------------
    LAT 0x11, 1
    LAT 0x12, 1

// ---------------- HOLD: CS held after the first frame ----------------
    SPIW SPI_CSMODE, 2
    LAT 0x21, 1                     // first frame asserts CS
    LAT 0x22, 0                     // held
    SPIW SPI_CSMODE, 2              // same value
    LAT 0x23, 0

// ---------------- csid ----------------
    SPIW SPI_CSID, 1                // different: CS deasserted
    LAT 0x31, 1
    LAT 0x32, 0
    SPIW SPI_CSID, 1                // same
    LAT 0x33, 0

// ---------------- csdef ----------------
    SPIW SPI_CSDEF, 0xB             // pin 2's default changes, not the selected pin 1
    LAT 0x41, 0
    SPIW SPI_CSDEF, 0x9             // selected pin 1's default changes: CS deasserted
    LAT 0x42, 1
    LAT 0x43, 0
    SPIW SPI_CSDEF, 0x9             // same
    LAT 0x44, 0
    SPIW SPI_CSDEF, 0xF             // selected pin changes back: deasserted again
    LAT 0x45, 1

// ---------------- OFF, then HOLD ----------------
    SPIW SPI_CSMODE, 3
    li a0, 0x51
    jal ra, spi_latency             // OFF frames: CS timing not checked
    SIGRE a1, 0x51
    li a0, 0x52
    jal ra, spi_latency
    SIGRE a1, 0x52
    SPIW SPI_CSMODE, 2              // HOLD: CS is asserted by the next frame, with cssck
    LAT 0x53, 1
    LAT 0x54, 0

// ---------------- AUTO and back to HOLD during a frame ----------------
    // CS is held.  Queue two frames; in the middle of the first, write csmode = AUTO, then HOLD.  CS is
    // deasserted after the first frame, so the second waits sckcs, intercs and cssck.
    SPIW SPI_TXDATA, 0x61
    SPIW SPI_TXDATA, 0x62
    DELAY 600                       // the first frame is shifting (it takes 1024 cycles)
    SPIW SPI_CSMODE, 0
    SPIW SPI_CSMODE, 2
    WAIT_IP 2, 2                    // first frame received
    csrr s1, mcycle
    SPIW SPI_RXMARK, 1
    WAIT_IP 2, 2                    // second frame received
    csrr s2, mcycle
    sub s2, s2, s1
    li t3, THRESH
    sltu t2, t3, s2
    SIGRE t2, 1                     // long gap: CS was deasserted between the frames
    CHKE SPI_RXDATA, 0x61
    CHKE SPI_RXDATA, 0x62
    SPIW SPI_RXMARK, 0
    // and CS is held again afterwards
    LAT 0x63, 0

    SPIW SPI_CSMODE, 0
    SPIW SPI_CSID, 0
    SPIW SPI_CSDEF, 0xF
    SPIW SPI_DELAY0, 0x00010001
    SPIW SPI_DELAY1, 0x00000001
    SPIW SPI_SCKDIV, 3

END_TESTS

SPI_HELPERS

// spi_latency: send frame a0 (the receive FIFO must be empty and rxmark = 0) and return a0 = cycles from
// the txdata write until ip.rxwm, a1 = the frame received.  Then wait for the trailing CS delays.
// Uses a0-a3, t2-t4.
spi_latency:
    mv a3, ra
    csrr a2, mcycle
    sw a0, SPI_TXDATA(s0)
1:
    lw t2, SPI_IP(s0)
    andi t2, t2, 2
    beqz t2, 1b
    csrr t2, mcycle
    sub a2, t2, a2
    lw a1, SPI_RXDATA(s0)
    li a0, 600                      // sckcs + intercs + slack
    jal ra, spi_delay
    mv a0, a2
    mv ra, a3
    ret

TEST_STACK_AND_DATA

EXPECT_END
