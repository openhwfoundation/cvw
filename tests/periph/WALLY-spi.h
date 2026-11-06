///////////////////////////////////////////
// WALLY-spi.h
//
// Purpose: SPI register map, signature macros, and helper routines shared by the WALLY-spi-*
//          stress tests.  The expected values in those tests follow the SiFive FE310-G002 Manual
//          v1p5, chapter 19 (Serial Peripheral Interface), cited by section, rather than the RTL.
//          Wally's SPI has 4 chip selects (cs_width = 4), a 12-bit divisor, and 8-entry FIFOs,
//          like SPI 1 of the FE310 (Table 62), and no flash interface (fctrl/ffmt absent).
//          Documented deviations (src/uncore/spi_apb.sv header): dual and quad protocols are not
//          supported, so fmt.proto reads 0.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

// The SPI tests run with interrupts disabled and poll ip (and the PLIC pending bits).  Frames come
// back through the internal loopback (SPI_LOOPBACK_TEST = 1 in the rv32gc/rv64gc configs), because
// the testbench ties SPIIn to 0.  Waits for received data poll ip.rxwm rather than rxdata, so that
// the tests do not depend on what a read of an empty rxdata does.
//
// Register use (besides those the test library reserves: t1, a6, s9-s11, sp, tp):
//   s0     SPI base address
//   s1-s8  free for the tests; preserved by the helpers
//   a0-a5, t0, t2-t6, ra: arguments and scratch, clobbered by the helpers

.equ SPI,          0x10040000
.equ SPI_SCKDIV,   0x00
.equ SPI_SCKMODE,  0x04
.equ SPI_CSID,     0x10
.equ SPI_CSDEF,    0x14
.equ SPI_CSMODE,   0x18
.equ SPI_DELAY0,   0x28
.equ SPI_DELAY1,   0x2C
.equ SPI_FMT,      0x40
.equ SPI_TXDATA,   0x48
.equ SPI_RXDATA,   0x4C
.equ SPI_TXMARK,   0x50
.equ SPI_RXMARK,   0x54
.equ SPI_IE,       0x70
.equ SPI_IP,       0x74
.equ SPI_MARK,     0x08        // reserved offset: the tests write markers here for waveform probes

.equ FMT_LSB,      0x4         // fmt.endian
.equ FMT_DIR_TX,   0x8         // fmt.dir
.equ FMT_LEN8,     0x80000

.equ PLIC_PRI_SPI,  0x0C000018  // priority of source 6
.equ PLIC_PENDING0, 0x0C001000  // interrupt pending bits of sources 31:0
.equ PLIC_EN0_M,    0x0C002000  // machine-mode enables of sources 31:0
.equ PLIC_THRESH_M, 0x0C200000
.equ PLIC_CLAIM_M,  0x0C200004  // machine-mode claim/complete
.equ SPI_IRQ,       6           // SPI interrupt source number

// Append register \reg to the signature and check it.
.macro SIGR reg
    SREG \reg, 0(t1)
    SIG_NEXT
.endm

// Append a constant to the signature.
.macro SIGI val
    li t2, \val
    SIGR t2
.endm

// Write constant \val (32 bits) to SPI register \off.
.macro SPIW off, val
    li t2, \val
    sw t2, \off(s0)
.endm

// Read SPI register \off into t2.
.macro SPIR off
    lw t2, \off(s0)
.endm

// Read SPI register \off into the signature.  lw sign-extends on RV64, so a value with bit 31 set
// is compared as SEXT32 of the 32-bit register value.
.macro CHK off
    lw t2, \off(s0)
    SIGR t2
.endm

// Read SPI register \off, keep the bits in \mask (12-bit immediate), and append the result.
.macro CHKM off, mask
    lw t2, \off(s0)
    andi t2, t2, \mask
    SIGR t2
.endm

// Write a marker \val to the reserved offset 0x08 (ignored by the SPI; seen by waveform probes).
.macro MARK val
    li t2, \val
    sw t2, SPI_MARK(s0)
.endm

// Wait until (ip & \mask) == \val; a0 = ip, or 0xBAD after a timeout.
.macro WAIT_IP mask, val
    li a0, \mask
    li a1, \val
    jal ra, spi_wait_ip
.endm

// Wait until the receive FIFO holds more than \n entries (rxmark = \n, ip.rxwm); leaves rxmark = \n.
// a0 = ip, or 0xBAD after a timeout.
.macro WAIT_RX n
    SPIW SPI_RXMARK, \n
    WAIT_IP 2, 2
.endm

// Wait \n cycles (mcycle).
.macro DELAY n
    li a0, \n
    jal ra, spi_delay
.endm


// Expected signature.  Each check emits its expected value into section .data.expect next to the
// check itself, so the table stays in step with the code.  EXPECT_BEGIN goes before the first check
// and EXPECT_END after END_TESTS; EXPECT_END adds the mcause (0xB) that terminate_test records.
.macro EXPECT_BEGIN
    .pushsection .data.expect, "aw"
    .align 3
    .globl expected_signature
expected_signature:
    .popsection
.endm

.macro EXPECT val
    .pushsection .data.expect, "aw"
    WORD SEXT32(\val)
    .popsection
.endm

.macro EXPECT_END
    EXPECT 0xB
    .pushsection .data.expect, "aw"
    .globl expected_signature_end
expected_signature_end:
    .popsection
.endm

// Checks with their expected values (32-bit values; bit 31 is sign extended on RV64 like lw).
.macro CHKE off, val
    CHK \off
    EXPECT \val
.endm

.macro CHKME off, mask, val
    CHKM \off, \mask
    EXPECT \val
.endm

.macro SIGRE reg, val
    SIGR \reg
    EXPECT \val
.endm

// Read rxdata/txdata and record bit 31 (rxdata.empty / txdata.full) as 0 or 1.
.macro CHKFLAG off, val
    lw t2, \off(s0)
    srli t2, t2, 31
    andi t2, t2, 1
    SIGR t2
    EXPECT \val
.endm

// Mask of the frame bits of a received value (19.12).
#define RXMASK(len, lsb) ((lsb) * ((1 << (len)) - 1) + (1 - (lsb)) * ((0xFF << (8 - (len))) & 0xFF))

// One scenario: configure, mark, send n (1-3) frames b0..b2, wait for them, release CS (HOLD), mark
// the end, and record the received frames (masked to the frame bits).  Cycles for the trailing CS
// delays come from \tail.
.macro SCEN id, div, mode, csid, csdef, csmode, d0, d1, len, lsb, n, b0, b1=0, b2=0, tail=400
    SPIW SPI_SCKDIV, \div
    SPIW SPI_SCKMODE, \mode
    SPIW SPI_CSID, \csid
    SPIW SPI_CSDEF, \csdef
    SPIW SPI_CSMODE, \csmode
    SPIW SPI_DELAY0, \d0
    SPIW SPI_DELAY1, \d1
    SPIW SPI_FMT, ((\len << 16) | (\lsb << 2))
    DELAY (4*(\div+1)+20)           // let SCK settle to the new polarity
    MARK (0x5C000000 | \id)
    SPIW SPI_TXDATA, \b0
.if \n > 1
    SPIW SPI_TXDATA, \b1
.endif
.if \n > 2
    SPIW SPI_TXDATA, \b2
.endif
    WAIT_RX (\n - 1)
    li a0, \tail
    jal ra, spi_delay
    SPIW SPI_CSMODE, 0              // AUTO releases a held CS
    li a0, (4*(\div+1)+20)
    jal ra, spi_delay
    MARK (0x5C008000 | \id)
    SPIW SPI_RXMARK, 0
    lw t2, SPI_RXDATA(s0)
    andi t2, t2, RXMASK(\len, \lsb)
    SIGRE t2, ((\b0) & RXMASK(\len, \lsb))
.if \n > 1
    lw t2, SPI_RXDATA(s0)
    andi t2, t2, RXMASK(\len, \lsb)
    SIGRE t2, ((\b1) & RXMASK(\len, \lsb))
.endif
.if \n > 2
    lw t2, SPI_RXDATA(s0)
    andi t2, t2, RXMASK(\len, \lsb)
    SIGRE t2, ((\b2) & RXMASK(\len, \lsb))
.endif
    CHKFLAG SPI_RXDATA, 1           // exactly n frames were received
.endm

// Helper routines.  Place SPI_HELPERS once in each test, after END_TESTS.
.macro SPI_HELPERS

// spi_wait_ip: poll until (ip & a0) == a1.  Returns a0 = ip, or 0xBAD after about 2000000 polls
// (several times the longest transfer any test makes).  Uses t2-t4.
spi_wait_ip:
    li t4, 2000000
1:
    lw t2, SPI_IP(s0)
    and t3, t2, a0
    beq t3, a1, 2f
    addi t4, t4, -1
    bnez t4, 1b
    li a0, 0xBAD
    ret
2:
    mv a0, t2
    ret

// spi_delay: wait a0 cycles (mcycle).  Uses t2, t3.
spi_delay:
    csrr t2, mcycle
1:
    csrr t3, mcycle
    sub t3, t3, t2
    bltu t3, a0, 1b
    ret

// spi_nops: execute exactly a0 nops (0 <= a0 < 1024) by jumping into a nop sled.  Uses t2, t3.
spi_nops:
    la t2, spi_nop_sled_end
    slli t3, a0, 2
    sub t2, t2, t3
    jr t2
    .rept 1024
    nop
    .endr
spi_nop_sled_end:
    ret

// spi_drain: read rxdata while ip.rxwm says the receive FIFO is not empty (rxmark = 0).  Returns
// a0 = number of frames read.  Uses a0, t2-t4.
spi_drain:
    li t2, 0
    sw t2, SPI_RXMARK(s0)
    li a0, 0
    li t4, 64
1:
    lw t2, SPI_IP(s0)
    andi t2, t2, 2
    beqz t2, 2f
    lw t3, SPI_RXDATA(s0)
    addi a0, a0, 1
    addi t4, t4, -1
    bnez t4, 1b
2:
    ret

// spi_idle: wait until the transmit FIFO is empty (txmark = 1, ip.txwm), then a0 more cycles so the
// frame in the shift register and the trailing delays finish, then drain the receive FIFO.
// Leaves txmark = 0 and rxmark = 0.  Returns a0 = number of frames drained.  Uses a0-a3, t2-t4.
spi_idle:
    mv a3, ra
    mv a2, a0
    li t2, 1
    sw t2, SPI_TXMARK(s0)
    WAIT_IP 1, 1
    sw zero, SPI_TXMARK(s0)
    mv a0, a2
    jal ra, spi_delay
    jal ra, spi_drain
    mv ra, a3
    ret

// spi_xfer: transmit a0, wait for one received frame (rxmark = 0), and return a0 = rxdata (32 bits,
// sign extended on RV64), or 0xBAD if nothing arrived.  The receive FIFO must be empty.  Uses a0-a2,
// t2-t4.
spi_xfer:
    mv a2, ra
    sw a0, SPI_TXDATA(s0)
    sw zero, SPI_RXMARK(s0)
    WAIT_IP 2, 2
    li t2, 0xBAD
    beq a0, t2, 1f
    lw a0, SPI_RXDATA(s0)
1:
    mv ra, a2
    ret
// spi_txwm_mask / spi_rxwm_mask: a0 = 8-bit mask whose bit m is ip.txwm (ip.rxwm) read with txmark
// (rxmark) = m.  Leaves txmark (rxmark) = 7.  Uses a0, t2-t4.
spi_txwm_mask:
    li a0, 0
    li t3, 0
1:
    sw t3, SPI_TXMARK(s0)
    lw t2, SPI_IP(s0)
    andi t2, t2, 1
    sll t2, t2, t3
    or a0, a0, t2
    addi t3, t3, 1
    li t4, 8
    blt t3, t4, 1b
    ret

spi_rxwm_mask:
    li a0, 0
    li t3, 0
1:
    sw t3, SPI_RXMARK(s0)
    lw t2, SPI_IP(s0)
    srli t2, t2, 1
    andi t2, t2, 1
    sll t2, t2, t3
    or a0, a0, t2
    addi t3, t3, 1
    li t4, 8
    blt t3, t4, 1b
    ret
.endm
