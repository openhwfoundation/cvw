///////////////////////////////////////////
// WALLY-spi-cs-01.S
//
// Purpose: SPI chip-select control (FE310-G002 19.8): HOLD keeps CS asserted after a frame and
//          deasserts it only when a different value is written to csmode or csid, or a csdef write
//          changes the state of the selected pin; OFF never drives CS; mode switches never assert CS
//          without a frame.  Software cannot see the CS pins, so the steps are separated by markers
//          written to the reserved offset 0x08 for a waveform probe of SPICS; WALLY-spi-timing-01
//          checks the software-visible effects.  The signature holds the frames received in loopback.
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

// Send frame \b, wait for it to come back, record it, then wait \t cycles for CS delays to finish.
.macro FRAME b, t=300
    li a0, \b
    jal ra, spi_xfer
    SIGRE a0, \b
    DELAY \t
.endm

.macro STEP n
    DELAY 300
    MARK (0x5CC00000 | \n)
.endm

INIT_TESTS

TRAP_HANDLER m

EXPECT_BEGIN

    li s0, SPI
    SPIW SPI_SCKDIV, 1

// ---- HOLD; csid change deasserts ----
    SPIW SPI_CSMODE, 2
    STEP 0                          // CS = F, nothing sent yet in HOLD
    FRAME 0x11
    STEP 1                          // CS0 asserted (E) after the frame
    SPIW SPI_CSID, 1                // a different csid: CS deasserted
    STEP 2                          // F
    FRAME 0x22                      // a frame on CS1
    STEP 3                          // D
    SPIW SPI_CSID, 1                // same value: no change
    STEP 4                          // D
    SPIW SPI_CSMODE, 2              // same value: no change
    STEP 5                          // D
    SPIW SPI_CSDEF, 0xF             // same value: the selected pin does not change
    STEP 6                          // D
    SPIW SPI_CSDEF, 0xB             // CS2 default changes, not the selected pin: no change
    STEP 7                          // pin 1 asserted (0), pin 2 now 0: 9
    SPIW SPI_CSDEF, 0xF
    STEP 8                          // D
    SPIW SPI_CSDEF, 0xD             // selected pin's default changes 1 -> 0: CS deasserted, pin 1 = 0
    STEP 9                          // D (pin 1 = csdef[1] = 0, inactive)
    SPIW SPI_CSDEF, 0xF             // CS stays deasserted, pin 1 = csdef[1] = 1
    STEP 10                         // F
    FRAME 0x33                      // assert again with a frame
    STEP 11                         // D
    SPIW SPI_CSMODE, 0              // AUTO: deasserted
    STEP 12                         // F

// ---- OFF never drives CS; switching modes does not assert CS without a frame ----
    SPIW SPI_CSMODE, 3
    FRAME 0x44
    STEP 13                         // F throughout
    SPIW SPI_CSMODE, 2              // HOLD: asserted only after the next frame
    STEP 14                         // F
    FRAME 0x55
    STEP 15                         // D
    SPIW SPI_CSMODE, 3              // OFF: deasserted
    STEP 16                         // F
    SPIW SPI_CSMODE, 2              // HOLD again: no frame yet
    STEP 17                         // F
    SPIW SPI_CSMODE, 0
    STEP 18                         // F

// ---- OFF -> AUTO at a slow clock: no CS pulse ----
    SPIW SPI_SCKDIV, 63
    SPIW SPI_CSMODE, 3
    FRAME 0x66, 3000
    STEP 19                         // F
    SPIW SPI_CSMODE, 0
    STEP 20                         // F, no pulse in between
    SPIW SPI_SCKDIV, 1
    SPIW SPI_CSID, 0
    STEP 21

END_TESTS

SPI_HELPERS

TEST_STACK_AND_DATA

EXPECT_END
