///////////////////////////////////////////
// WALLY-spi-intr-01.S
//
// Purpose: SPI interrupt (FE310-G002 19.15): the SPI interrupt request is the OR of the ip bits
//          enabled in ie, for txwm and rxwm separately, and reaches the PLIC as source 6 and mip.MEIP.
//          The test polls with machine interrupts disabled.
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

// Record the PLIC pending bit of source 6.
.macro CHK_PEND val
    li t3, PLIC_PENDING0
    lw t2, 0(t3)
    srli t2, t2, SPI_IRQ
    andi t2, t2, 1
    SIGRE t2, \val
.endm

// Record mip.MEIP.
.macro CHK_MEIP val
    csrr t2, mip
    srli t2, t2, 11
    andi t2, t2, 1
    SIGRE t2, \val
.endm

// Claim (record the ID) and complete.
.macro CLAIM val
    li t3, PLIC_CLAIM_M
    lw t2, 0(t3)
    sw t2, 0(t3)
    SIGRE t2, \val
.endm

INIT_TESTS

TRAP_HANDLER m

EXPECT_BEGIN

    li s0, SPI
    csrci mstatus, 8                // MIE off: poll only
    li t3, PLIC_PRI_SPI
    li t2, 7
    sw t2, 0(t3)
    li t3, PLIC_EN0_M
    li t2, (1 << SPI_IRQ)
    sw t2, 0(t3)
    li t3, PLIC_THRESH_M
    sw zero, 0(t3)
    SPIW SPI_SCKDIV, 1

// ---------------- txwm ----------------
    SPIW SPI_TXMARK, 1              // ip.txwm = 1 (0 entries < 1)
    CHKE SPI_IP, 1
    CHK_PEND 0                      // ie.txwm = 0: no request
    CHK_MEIP 0
    SPIW SPI_IE, 2                  // only rxwm enabled: still no request
    CHK_PEND 0
    SPIW SPI_IE, 1
    CHK_PEND 1
    CHK_MEIP 1
    CLAIM SPI_IRQ
    CHK_PEND 1                      // still requesting: pending again after completion
    SPIW SPI_IE, 0
    CLAIM SPI_IRQ
    CHK_PEND 0
    CHK_MEIP 0
    SPIW SPI_IE, 1
    SPIW SPI_TXMARK, 0              // condition gone (0 entries not < 0)
    CHKE SPI_IP, 0
    CLAIM SPI_IRQ                   // the request was latched while ie and txmark changed
    CHK_PEND 0
    CLAIM 0                         // nothing left

// ---------------- rxwm ----------------
    SPIW SPI_IE, 2
    SPIW SPI_RXMARK, 0
    CHK_PEND 0
    SPIW SPI_TXDATA, 0x3E
    WAIT_IP 2, 2
    CHK_PEND 1
    CHK_MEIP 1
    CLAIM SPI_IRQ
    CHKE SPI_RXDATA, 0x3E           // condition cleared by the read
    CHKE SPI_IP, 0
    CHK_PEND 1                      // re-pended at the completion above, while still requesting
    CLAIM SPI_IRQ
    CHK_PEND 0
    CLAIM 0
    // rxwm masked by ie while the condition holds
    SPIW SPI_IE, 1                  // txwm enabled, but txmark = 0: no condition
    SPIW SPI_TXDATA, 0x4F
    WAIT_IP 2, 2
    CHK_PEND 0
    SPIW SPI_IE, 3
    CHK_PEND 1
    CLAIM SPI_IRQ
    SPIW SPI_IE, 0
    CLAIM SPI_IRQ                   // re-pended at completion of the first claim
    CHKE SPI_RXDATA, 0x4F
    CHK_PEND 0
    CLAIM 0

    SPIW SPI_IE, 0
    SPIW SPI_SCKDIV, 3

END_TESTS

SPI_HELPERS

TEST_STACK_AND_DATA

EXPECT_END
