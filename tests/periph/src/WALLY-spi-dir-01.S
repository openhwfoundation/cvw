///////////////////////////////////////////
// WALLY-spi-dir-01.S
//
// Purpose: SPI fmt.dir (FE310-G002 19.10, Tables 74 and 77): dir is a read/write field, and with
//          dir = Tx the receive FIFO is not populated.  Also the sequence the Linux spi-sifive driver
//          uses: a transmit-only transfer (dir = Tx, completion by ip.txwm with txmark = 1) followed by
//          a full-duplex transfer whose received frames must be the new ones.
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
    SPIW SPI_SCKDIV, 1

// ---------------- dir reads back ----------------
    SPIW SPI_FMT, (FMT_LEN8 | FMT_DIR_TX)
    CHKE SPI_FMT, 0x00080008
    SPIW SPI_FMT, FMT_LEN8
    CHKE SPI_FMT, 0x00080000

// ---------------- dir = Tx: nothing is received ----------------
    SPIW SPI_FMT, (FMT_LEN8 | FMT_DIR_TX)
    SPIW SPI_TXDATA, 0x5A
    SPIW SPI_TXDATA, 0xA5
    SPIW SPI_TXDATA, 0x3C
    li a0, 400
    jal ra, spi_idle
    SIGRE a0, 0                     // frames found in the receive FIFO
    CHKFLAG SPI_RXDATA, 1

// ---------------- dir = Rx: frames are received ----------------
    SPIW SPI_FMT, FMT_LEN8
    SPIW SPI_TXDATA, 0x69
    WAIT_RX 0
    CHKE SPI_RXDATA, 0x69

// ---------------- Linux spi-sifive sequence: tx-only transfer, then full duplex ----------------
    SPIW SPI_TXMARK, 1
    SPIW SPI_FMT, (FMT_LEN8 | FMT_DIR_TX)
    SPIW SPI_TXDATA, 0x40           // e.g. an SD command, no receive buffer
    SPIW SPI_TXDATA, 0x00
    SPIW SPI_TXDATA, 0x95
    WAIT_IP 1, 1                    // the driver's completion test for a tx-only transfer
    DELAY 200                       // let the last frame finish
    SPIW SPI_FMT, FMT_LEN8          // next transfer has a receive buffer
    SPIW SPI_TXDATA, 0xFF
    SPIW SPI_TXDATA, 0x01
    SPIW SPI_RXMARK, 1              // n_words - 1
    WAIT_IP 2, 2
    CHKE SPI_RXDATA, 0xFF           // the frames of this transfer, not the tx-only ones
    CHKE SPI_RXDATA, 0x01
    CHKFLAG SPI_RXDATA, 1
    SPIW SPI_TXMARK, 0
    SPIW SPI_RXMARK, 0
    SPIW SPI_SCKDIV, 3

END_TESTS

SPI_HELPERS

TEST_STACK_AND_DATA

EXPECT_END
