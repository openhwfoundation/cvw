///////////////////////////////////////////
// WALLY-spi-midxfer-01.S
//
// Purpose: SPI register writes while a frame is in flight, as drivers make them.  FE310-G002 19.1:
//          "Hardware interlocks ensure that the current transfer completes before mode transitions
//          and control register updates take effect."  Wally has no interlock for real changes
//          (PR 1050), so this test only makes writes that a driver makes between transfers:
//          1. sckdiv rewritten with its current value during frames (spi-sifive writes sckdiv for
//             every transfer).
//          2. fmt rewritten with its current value during frames.
//          3. The spi-sifive sequence: a transmit-only transfer (dir = Tx) whose completion is
//             ip.txwm with txmark = 1, which is set while the last frame is still shifting; the next
//             transfer then writes sckdiv and fmt (dir = Rx) at once.  The frame in flight belongs to
//             the transmit-only transfer, so it must not appear in the receive FIFO.
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

INIT_TESTS

TRAP_HANDLER m

EXPECT_BEGIN

    li s0, SPI

// ---------------- 1. sckdiv rewritten with the same value during frames ----------------
    SPIW SPI_SCKDIV, 7
    SPIW SPI_TXDATA, 0xC6
    SPIW SPI_TXDATA, 0x39
    SPIW SPI_TXDATA, 0xA5
    li s1, 40
1:
    SPIW SPI_SCKDIV, 7
    DELAY 23
    addi s1, s1, -1
    bnez s1, 1b
    WAIT_RX 2
    CHKE SPI_RXDATA, 0xC6
    CHKE SPI_RXDATA, 0x39
    CHKE SPI_RXDATA, 0xA5
    CHKFLAG SPI_RXDATA, 1

// ---------------- 2. fmt rewritten with the same value during frames ----------------
    SPIW SPI_TXDATA, 0x1E
    SPIW SPI_TXDATA, 0xE1
    li s1, 40
2:
    SPIW SPI_FMT, FMT_LEN8
    DELAY 17
    addi s1, s1, -1
    bnez s1, 2b
    WAIT_RX 1
    CHKE SPI_RXDATA, 0x1E
    CHKE SPI_RXDATA, 0xE1
    CHKFLAG SPI_RXDATA, 1
    SPIW SPI_RXMARK, 0

// ---------------- 3. spi-sifive: tx-only transfer, then a full-duplex transfer at once ----------------
    SPIW SPI_TXMARK, 1
    SPIW SPI_FMT, (FMT_LEN8 | FMT_DIR_TX)
    SPIW SPI_TXDATA, 0x51
    SPIW SPI_TXDATA, 0x00
    SPIW SPI_TXDATA, 0xFE
    WAIT_IP 1, 1                    // "transmission complete" for a tx-only transfer
    SPIW SPI_SCKDIV, 7              // sifive_spi_prep_transfer
    SPIW SPI_FMT, FMT_LEN8
    SPIW SPI_TXDATA, 0xFF
    SPIW SPI_TXDATA, 0xFF
    SPIW SPI_RXMARK, 1
    WAIT_IP 2, 2
    CHKE SPI_RXDATA, 0xFF
    CHKE SPI_RXDATA, 0xFF
    DELAY 400
    CHKFLAG SPI_RXDATA, 1           // nothing else was received
    SPIW SPI_TXMARK, 0
    SPIW SPI_RXMARK, 0
    SPIW SPI_SCKDIV, 3

END_TESTS

SPI_HELPERS

TEST_STACK_AND_DATA

EXPECT_END
