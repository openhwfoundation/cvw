///////////////////////////////////////////
// WALLY-spi-regs-01.S
//
// Purpose: SPI register file: reset values (FE310-G002 19.4-19.15), writable bits of every register,
//          read-only fields, reserved offsets, registers holding their values independently, and
//          sub-word accesses.  Expected values follow the FE310-G002 manual (see
//          WALLY-spi.h), not the RTL.
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

// ---------------- Reset values ----------------
    CHKE SPI_SCKDIV,  0x3           // 19.4: div = 0x3
    CHKE SPI_SCKMODE, 0x0           // 19.5
    CHKE SPI_CSID,    0x0           // 19.6
    CHKE SPI_CSDEF,   0xF           // 19.7: all 1s for cs_width = 4
    CHKE SPI_CSMODE,  0x0           // 19.8: AUTO
    CHKE SPI_DELAY0,  0x00010001    // 19.9: cssck = 1, sckcs = 1
    CHKE SPI_DELAY1,  0x00000001    // 19.9: intercs = 1, interxfr = 0
    CHKE SPI_FMT,     0x00080000    // 19.10: non-flash controller: single, Rx, MSB, len 8
    CHKE SPI_TXDATA,  0x0           // 19.11: not full; data reads 0
    CHKFLAG SPI_RXDATA, 1           // 19.12: receive FIFO empty
    CHKE SPI_TXMARK,  0x0           // 19.13: non-flash controller: 0
    CHKE SPI_RXMARK,  0x0           // 19.14
    CHKE SPI_IE,      0x0           // 19.15
    CHKE SPI_IP,      0x0           // 19.15: 0 entries is not < txmark 0 and not > rxmark 0

// ---------------- Writable bits: all ones, then zero ----------------
    SPIW SPI_SCKDIV, 0xFFFFFFFF
    CHKE SPI_SCKDIV, 0xFFF          // div_width = 12
    SPIW SPI_SCKDIV, 0x0
    CHKE SPI_SCKDIV, 0x0
    SPIW SPI_SCKDIV, 0xA5A
    CHKE SPI_SCKDIV, 0xA5A
    SPIW SPI_SCKDIV, 0x3

    SPIW SPI_SCKMODE, 0xFFFFFFFF
    CHKE SPI_SCKMODE, 0x3           // pha, pol
    SPIW SPI_SCKMODE, 0x2
    CHKE SPI_SCKMODE, 0x2
    SPIW SPI_SCKMODE, 0x1
    CHKE SPI_SCKMODE, 0x1
    SPIW SPI_SCKMODE, 0x0
    CHKE SPI_SCKMODE, 0x0

    SPIW SPI_CSID, 0xFFFFFFFF
    CHKE SPI_CSID, 0x3              // log2(cs_width) = 2 bits
    SPIW SPI_CSID, 0x2
    CHKE SPI_CSID, 0x2
    SPIW SPI_CSID, 0x5                // only the implemented bits are kept
    CHKE SPI_CSID, 0x1
    SPIW SPI_CSID, 0x0
    CHKE SPI_CSID, 0x0

    SPIW SPI_CSDEF, 0xFFFFFFF0
    CHKE SPI_CSDEF, 0x0             // cs_width = 4 bits
    SPIW SPI_CSDEF, 0x5
    CHKE SPI_CSDEF, 0x5
    SPIW SPI_CSDEF, 0xFFFFFFFF
    CHKE SPI_CSDEF, 0xF

    SPIW SPI_CSMODE, 0xFFFFFFFF
    CHKE SPI_CSMODE, 0x3            // OFF
    SPIW SPI_CSMODE, 0x2
    CHKE SPI_CSMODE, 0x2            // HOLD
    SPIW SPI_CSMODE, 0x0
    CHKE SPI_CSMODE, 0x0            // AUTO

    SPIW SPI_DELAY0, 0xFFFFFFFF
    CHKE SPI_DELAY0, 0x00FF00FF     // cssck [7:0], sckcs [23:16]
    SPIW SPI_DELAY0, 0x00A5005A
    CHKE SPI_DELAY0, 0x00A5005A
    SPIW SPI_DELAY0, 0x0
    CHKE SPI_DELAY0, 0x0
    SPIW SPI_DELAY0, 0x00010001

    SPIW SPI_DELAY1, 0xFFFFFFFF
    CHKE SPI_DELAY1, 0x00FF00FF     // intercs [7:0], interxfr [23:16]
    SPIW SPI_DELAY1, 0x005A00A5
    CHKE SPI_DELAY1, 0x005A00A5
    SPIW SPI_DELAY1, 0x0
    CHKE SPI_DELAY1, 0x0
    SPIW SPI_DELAY1, 0x00000001

    // fmt: len values 0-8 are legal (19.10); proto reads 0 because only single is implemented
    SPIW SPI_FMT, 0x0008000C
    CHKE SPI_FMT, 0x0008000C        // dir = Tx, endian = LSB: dir is RW (Table 74)
    SPIW SPI_FMT, 0xFFF3FFF7          // reserved bits, len 3, endian, no dir; proto = 3 is not implemented
    CHKE SPI_FMT, 0x00030004
    SPIW SPI_FMT, 0x00000008
    CHKE SPI_FMT, 0x00000008        // len 0, dir = Tx
    SPIW SPI_FMT, 0x00050000
    CHKE SPI_FMT, 0x00050000
    SPIW SPI_FMT, 0x00080000

    SPIW SPI_TXMARK, 0xFFFFFFFF
    CHKE SPI_TXMARK, 0x7            // [2:0]
    SPIW SPI_TXMARK, 0x5
    CHKE SPI_TXMARK, 0x5
    SPIW SPI_TXMARK, 0x0
    CHKE SPI_TXMARK, 0x0

    SPIW SPI_RXMARK, 0xFFFFFFFF
    CHKE SPI_RXMARK, 0x7            // [2:0]
    SPIW SPI_RXMARK, 0x2
    CHKE SPI_RXMARK, 0x2
    SPIW SPI_RXMARK, 0x0
    CHKE SPI_RXMARK, 0x0

    SPIW SPI_IE, 0xFFFFFFFF
    CHKE SPI_IE, 0x3                // txwm, rxwm
    SPIW SPI_IE, 0x2
    CHKE SPI_IE, 0x2
    SPIW SPI_IE, 0x0
    CHKE SPI_IE, 0x0

    // ip is read-only (19.15)
    SPIW SPI_IP, 0xFFFFFFFF
    CHKE SPI_IP, 0x0
    // txwm follows the transmit FIFO count against txmark: 0 < 1
    SPIW SPI_TXMARK, 0x1
    CHKE SPI_IP, 0x1
    SPIW SPI_IP, 0x0                  // writing 0 does not clear a pending condition
    CHKE SPI_IP, 0x1
    SPIW SPI_TXMARK, 0x0
    CHKE SPI_IP, 0x0

// ---------------- Registers hold their values independently ----------------
    SPIW SPI_SCKDIV, 0x123
    SPIW SPI_SCKMODE, 0x2
    SPIW SPI_CSID, 0x3
    SPIW SPI_CSDEF, 0x9
    SPIW SPI_CSMODE, 0x3
    SPIW SPI_DELAY0, 0x00070003
    SPIW SPI_DELAY1, 0x00090005
    SPIW SPI_FMT, 0x00060004
    SPIW SPI_TXMARK, 0x6
    SPIW SPI_RXMARK, 0x4
    SPIW SPI_IE, 0x1
    CHKE SPI_SCKDIV, 0x123
    CHKE SPI_SCKMODE, 0x2
    CHKE SPI_CSID, 0x3
    CHKE SPI_CSDEF, 0x9
    CHKE SPI_CSMODE, 0x3
    CHKE SPI_DELAY0, 0x00070003
    CHKE SPI_DELAY1, 0x00090005
    CHKE SPI_FMT, 0x00060004
    CHKE SPI_TXMARK, 0x6
    CHKE SPI_RXMARK, 0x4
    CHKE SPI_IE, 0x1
    CHKE SPI_IP, 0x1                // 0 entries < txmark 6; 0 entries not > rxmark 4

// ---------------- Reserved offsets ----------------
    // Writes to reserved offsets change nothing; reads return 0.  s1 = OR of all reserved reads.
    la s2, reserved_offsets
    li s1, 0
1:
    lw t3, 0(s2)
    bltz t3, 2f
    add t3, t3, s0
    li t2, -1
    sw t2, 0(t3)
    lw t2, 0(t3)
    or s1, s1, t2
    addi s2, s2, 4
    j 1b
2:
    SIGRE s1, 0
    CHKE SPI_SCKDIV, 0x123
    CHKE SPI_SCKMODE, 0x2
    CHKE SPI_CSID, 0x3
    CHKE SPI_CSDEF, 0x9
    CHKE SPI_CSMODE, 0x3
    CHKE SPI_DELAY0, 0x00070003
    CHKE SPI_DELAY1, 0x00090005
    CHKE SPI_FMT, 0x00060004
    CHKE SPI_TXMARK, 0x6
    CHKE SPI_RXMARK, 0x4
    CHKE SPI_IE, 0x1
    CHKFLAG SPI_RXDATA, 1           // nothing was transmitted
    CHKE SPI_TXDATA, 0x0

// ---------------- Sub-word accesses ----------------
    // 19.3: the SPI needs only naturally aligned 32-bit accesses.  Wally's PMA (adrdecs.sv) makes the
    // SPI word-only, so byte and halfword accesses take an access fault (the trap handler records
    // mcause and skips the instruction) and leave the register unchanged.
    li t2, 0x77
    lbu t2, (SPI_SCKDIV+0)(s0)
    EXPECT 5                        // load access fault
    SIGRE t2, 0x77                  // destination not written
    li t2, 0x77
    lhu t2, (SPI_FMT+2)(s0)
    EXPECT 5
    SIGRE t2, 0x77
    li t2, 0x0
    sb t2, (SPI_SCKDIV+0)(s0)
    EXPECT 7                        // store access fault
    CHKE SPI_SCKDIV, 0x123
    li t2, 0x0
    sh t2, (SPI_FMT+2)(s0)
    EXPECT 7
    CHKE SPI_FMT, 0x00060004

// ---------------- Back to reset values ----------------
    SPIW SPI_SCKDIV, 0x3
    SPIW SPI_SCKMODE, 0x0
    SPIW SPI_CSID, 0x0
    SPIW SPI_CSDEF, 0xF
    SPIW SPI_CSMODE, 0x0
    SPIW SPI_DELAY0, 0x00010001
    SPIW SPI_DELAY1, 0x00000001
    SPIW SPI_FMT, 0x00080000
    SPIW SPI_TXMARK, 0x0
    SPIW SPI_RXMARK, 0x0
    SPIW SPI_IE, 0x0
    CHKE SPI_IP, 0x0

END_TESTS

SPI_HELPERS

reserved_offsets:
    .word 0x08, 0x0C, 0x1C, 0x20, 0x24, 0x30, 0x34, 0x38, 0x3C, 0x44, 0x58, 0x5C, 0x60, 0x64, 0x68, 0x6C
    .word 0x78, 0x7C, 0x80, 0x84, 0x88, 0x8C, 0x90, 0x94, 0x98, 0x9C, 0xA0, 0xA4, 0xA8, 0xAC, 0xB0, 0xB4
    .word 0xB8, 0xBC, 0xC0, 0xC4, 0xC8, 0xCC, 0xD0, 0xD4, 0xD8, 0xDC, 0xE0, 0xE4, 0xE8, 0xEC, 0xF0, 0xF4
    .word 0xF8, 0xFC, -1

TEST_STACK_AND_DATA

EXPECT_END
