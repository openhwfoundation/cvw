///////////////////////////////////////////
// WALLY-spi-fifo-01.S
//
// Purpose: SPI FIFOs (FE310-G002 19.11-19.15): the txdata full flag at exactly 8 entries and writes
//          ignored while full; the rxdata empty flag, reads that dequeue, and writes to rxdata that
//          are ignored; FIFO order through many fills and drains that wrap the pointers; and ip.txwm /
//          ip.rxwm at every FIFO count for every txmark / rxmark value, at fast and slow SCK.
//          Expected values follow the FE310-G002 manual (see WALLY-spi.h), not the RTL.  The manual
//          leaves the rxdata data field invalid when empty is set; Wally defines it as 0, and the test
//          checks that, so software that tests empty with a sign branch never reads X.
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

// Record 1 if the last wait did not time out (a0 != 0xBAD).
.macro OK_A0
    li t2, 0xBAD
    sub t2, a0, t2
    snez t2, t2
    SIGRE t2, 1
.endm

// Fill the transmit FIFO while frame \base is in the shift register (sckdiv = 255: a frame takes
// about 5600 cycles).  For each count 0..8 record the full flag and the txwm mask over txmark 0..7
// (19.15: txwm when count < txmark); the 9th write is ignored (19.11).  Then receive all 9 frames.
.macro TXFULL base
    SPIW SPI_SCKDIV, 255
    SPIW SPI_TXMARK, 1
    SPIW SPI_TXDATA, \base
    WAIT_IP 1, 1                    // transmit FIFO empty: \base is in the shift register
    OK_A0
    csrr s3, mcycle
    .set k, 0
    .rept 8
    CHKFLAG SPI_TXDATA, 0
    jal ra, spi_txwm_mask
    SIGRE a0, (0xFF & ~((1 << (k + 1)) - 1))
    SPIW SPI_TXDATA, (\base + 1 + k)
    .set k, k + 1
    .endr
    CHKFLAG SPI_TXDATA, 1           // 8 entries: full
    jal ra, spi_txwm_mask
    SIGRE a0, 0
    SPIW SPI_TXDATA, (\base + 0x40) // ignored
    CHKFLAG SPI_TXDATA, 1
    csrr t2, mcycle
    sub t2, t2, s3
    li t3, 3500
    sltu t2, t2, t3
    SIGRE t2, 1                     // the FIFO checks finished well within one frame
    SPIW SPI_TXMARK, 0
    WAIT_RX 0
    OK_A0
    CHK SPI_RXDATA
    EXPECT \base
    WAIT_RX 7
    OK_A0
    .set k, 0
    .rept 8
    CHK SPI_RXDATA
    EXPECT (\base + 1 + k)
    .set k, k + 1
    .endr
    DELAY 12000
    CHKFLAG SPI_RXDATA, 1           // the ignored write was not sent
    SPIW SPI_RXMARK, 0
.endm

// Send \n frames (1-8) with values \v, \v+0x0B, ... and read them back in order (sckdiv = 0).
.macro ROUND n, v
    .set k, 0
    .rept \n
    SPIW SPI_TXDATA, ((\v + 0x0B * k) & 0xFF)
    .set k, k + 1
    .endr
    WAIT_RX (\n - 1)
    .set k, 0
    .rept \n
    CHK SPI_RXDATA
    EXPECT ((\v + 0x0B * k) & 0xFF)
    .set k, k + 1
    .endr
    CHKE SPI_RXDATA, 0x80000000     // empty: the data field reads 0, not the stale FIFO entry
.endm

INIT_TESTS

TRAP_HANDLER m

EXPECT_BEGIN

    li s0, SPI

// ---------------- Transmit FIFO full flag and txwm, pointers from reset ----------------
    TXFULL 0x10

// ---------------- Receive FIFO: rxwm at every count, filling then draining ----------------
    SPIW SPI_SCKDIV, 0
    jal ra, spi_rxwm_mask
    SIGRE a0, 0x00                  // 0 entries: never > rxmark
    CHKE SPI_RXDATA, 0x80000000     // empty after reset: the data field reads 0, not unwritten FIFO storage
    .set k, 1
    .rept 8
    SPIW SPI_TXDATA, (0x60 + k)
    WAIT_RX (k - 1)
    jal ra, spi_rxwm_mask
    SIGRE a0, ((1 << k) - 1)        // 19.15: rxwm when count > rxmark
    .set k, k + 1
    .endr
    // drain at a slow SCK, so a stale full flag would last a long time
    SPIW SPI_SCKDIV, 255
    .set k, 7
    .rept 8
    CHK SPI_RXDATA
    EXPECT (0x60 + 8 - k)
    jal ra, spi_rxwm_mask
    SIGRE a0, ((1 << k) - 1)
    .set k, k - 1
    .endr
    CHKFLAG SPI_RXDATA, 1

// ---------------- rxdata writes are ignored (19.12) ----------------
    SPIW SPI_SCKDIV, 0
    SPIW SPI_TXDATA, 0xA1
    SPIW SPI_TXDATA, 0xB2
    WAIT_RX 1
    OK_A0
    SPIW SPI_RXDATA, 0x55           // must not dequeue
    CHK SPI_RXDATA
    EXPECT 0xA1
    SPIW SPI_RXDATA, 0x66
    CHK SPI_RXDATA
    EXPECT 0xB2
    CHKFLAG SPI_RXDATA, 1
    SPIW SPI_RXDATA, 0x77           // write while empty
    SPIW SPI_TXDATA, 0xC3
    WAIT_RX 0
    CHK SPI_RXDATA
    EXPECT 0xC3
    CHKFLAG SPI_RXDATA, 1

// ---------------- FIFO order through fills and drains that wrap the pointers ----------------
    SPIW SPI_RXMARK, 0
    ROUND 3, 0x21
    ROUND 8, 0x35
    ROUND 5, 0x47
    ROUND 7, 0x59
    ROUND 1, 0x6B
    ROUND 8, 0x7D
    ROUND 6, 0x8F
    ROUND 2, 0xA1
    ROUND 4, 0xB3

// ---------------- Transmit FIFO full flag again, from wrapped pointers ----------------
    TXFULL 0xC0

    SPIW SPI_SCKDIV, 3
    SPIW SPI_TXMARK, 0
    SPIW SPI_RXMARK, 0
    CHKE SPI_IP, 0

END_TESTS

SPI_HELPERS

TEST_STACK_AND_DATA

EXPECT_END
