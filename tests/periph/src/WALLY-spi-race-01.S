///////////////////////////////////////////
// WALLY-spi-race-01.S
//
// Purpose: SPI receive FIFO timing races.
//          1. Reading rxdata while a frame is arriving: a read that finds the FIFO empty must not
//             dequeue the frame that arrives during the read (FE310-G002 19.12: reading rxdata
//             dequeues a frame; with empty set the data field is not valid, so nothing is dequeued).
//             The read time is swept over 64 cycle offsets so that some read lands on the arrival.
//          2. A full receive FIFO with one frame read out before the next frame completes: the FIFO
//             has room when the frame completes, so it must be kept (9 frames received in total).
//             The read time is swept from about one half to four SCK half periods before the
//             frame's last SCK edge.  (A read after the last SCK edge is not checked: the FIFO was
//             full when the frame completed, and the manual does not say what happens on overflow.)
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

// ---------------- 1. Read rxdata as the frame arrives ----------------
// Each trial sends one frame, waits s1 nops (s1 = 0..63), reads rxdata once, waits for the transfer to
// end, and drains the FIFO (by ip.rxwm).  The frame must be delivered exactly once: by the single read
// if it found the FIFO not empty, otherwise by the drain.
    SPIW SPI_SCKDIV, 0
    li s1, 0                        // offset
    li s2, 0                        // frames lost (not delivered)
    li s3, 0                        // frames delivered twice or with the wrong value
1:
    andi s5, s1, 0x3F
    addi s5, s5, 0x41               // frame value
    sw s5, SPI_TXDATA(s0)
    mv a0, s1
    jal ra, spi_nops
    lw t2, SPI_RXDATA(s0)
    srli t3, t2, 31                 // empty flag (bit 31); the data bits are not valid when it is set
    andi t3, t3, 1
    xori s4, t3, 1                  // s4 = 1 if the read delivered the frame
    beqz s4, 2f
    andi t2, t2, 0xFF
    beq t2, s5, 2f
    addi s3, s3, 1                  // wrong value
2:
    DELAY 100
    jal ra, spi_drain
    add s4, s4, a0                  // deliveries
    bnez s4, 3f
    addi s2, s2, 1
3:
    li t2, 2
    blt s4, t2, 4f
    addi s3, s3, 1
4:
    addi s1, s1, 1
    li t2, 64
    blt s1, t2, 1b
    SIGRE s2, 0
    SIGRE s3, 0

// ---------------- 2. Read from a full receive FIFO just before the next frame completes ----------------
// sckdiv = 31: half period 32 cycles.  Each trial queues 9 frames, measures when the 8th arrives (ip.rxwm,
// rxmark = 7) and the frame period (from the 7th), then reads one frame at (8th + period - s6) and
// counts every frame received.  s6 sweeps 96, 104, ..., 200 cycles before the expected arrival (the
// measurement includes the polling latency, so the read lands roughly 60-80 cycles later than s6 says,
// still before the frame's last SCK edge; checked with the pin probe).
    SPIW SPI_SCKDIV, 31
    .set lead, 96
    .rept 14
    li s6, lead
    jal ra, full_trial
    SIGRE a0, 0                     // 9 frames received (difference from 9)
    SIGRE s7, 0x90                  // the first frame
    .set lead, lead + 8
    .endr

    SPIW SPI_SCKDIV, 3
    SPIW SPI_RXMARK, 0

END_TESTS

SPI_HELPERS

// full_trial: one trial of part 2 with the read s6 cycles before the expected arrival of the 9th
// frame.  Returns a0 = frames received - 9 and s7 = the frame read first (low 11 bits).
full_trial:
    mv s5, ra
    SPIW SPI_TXMARK, 1
    SPIW SPI_TXDATA, 0x90
    WAIT_IP 1, 1                    // frame 0x90 in the shift register
    .set k, 1
    .rept 8
    SPIW SPI_TXDATA, (0x90 + k)
    .set k, k + 1
    .endr
    SPIW SPI_TXMARK, 0
    WAIT_RX 6                       // 7 frames
    csrr s7, mcycle
    WAIT_RX 7                       // 8 frames: the FIFO is full
    csrr s8, mcycle
    sub t5, s8, s7                  // frame period
    add t5, t5, s8
    sub t5, t5, s6                  // read time
1:
    csrr t2, mcycle
    bltu t2, t5, 1b
    lw s7, SPI_RXDATA(s0)           // frees one entry
    DELAY 3000
    jal ra, spi_drain
    addi a0, a0, 1                  // frames received, including the one read above
    addi a0, a0, -9
    andi s7, s7, 0x7FF
    mv ra, s5
    ret

TEST_STACK_AND_DATA

EXPECT_END
