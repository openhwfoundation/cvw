///////////////////////////////////////////////////////////////////////
// spi.h
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Header file for interfaceing with the SPI peripheral
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#pragma once
#ifndef SPI_HEADER
#define SPI_HEADER

#include <stdint.h>

#define SPI_BASE              0x13000 /* Base address of SPI device used for SDC */

/* register offsets */
#define SPI_SCKDIV            SPI_BASE + 0x00 /* Serial clock divisor */
#define SPI_SCKMODE           SPI_BASE + 0x04 /* Serial clock mode */
#define SPI_CSID              SPI_BASE + 0x10 /* Chip select ID */
#define SPI_CSDEF             SPI_BASE + 0x14 /* Chip select default */
#define SPI_CSMODE            SPI_BASE + 0x18 /* Chip select mode */
#define SPI_DELAY0            SPI_BASE + 0x28 /* Delay control 0 */
#define SPI_DELAY1            SPI_BASE + 0x2c /* Delay control 1 */
#define SPI_FMT               SPI_BASE + 0x40 /* Frame format */
#define SPI_TXDATA            SPI_BASE + 0x48 /* Tx FIFO data */
#define SPI_RXDATA            SPI_BASE + 0x4c /* Rx FIFO data */
#define SPI_TXMARK            SPI_BASE + 0x50 /* Tx FIFO [<35;39;29Mwatermark */
#define SPI_RXMARK            SPI_BASE + 0x54 /* Rx FIFO watermark */

/* Non-implemented
#define SPI_FCTRL             SPI_BASE + 0x60 // SPI flash interface control
#define SPI_FFMT              SPI_BASE + 0x64 // SPI flash instruction format
*/
#define SPI_IE                SPI_BASE + 0x70 /* Interrupt Enable Register */
#define SPI_IP                SPI_BASE + 0x74 /* Interrupt Pendings Register */

/* delay0 bits */
#define SIFIVE_SPI_DELAY0_CSSCK(x)       ((uint32_t)(x))
#define SIFIVE_SPI_DELAY0_CSSCK_MASK     0xffU
#define SIFIVE_SPI_DELAY0_SCKCS(x)       ((uint32_t)(x) << 16)
#define SIFIVE_SPI_DELAY0_SCKCS_MASK     (0xffU << 16)

/* delay1 bits */
#define SIFIVE_SPI_DELAY1_INTERCS(x)     ((uint32_t)(x))
#define SIFIVE_SPI_DELAY1_INTERCS_MASK   0xffU
#define SIFIVE_SPI_DELAY1_INTERXFR(x)    ((uint32_t)(x) << 16)
#define SIFIVE_SPI_DELAY1_INTERXFR_MASK  (0xffU << 16)

/* csmode bits */
#define SIFIVE_SPI_CSMODE_MODE_AUTO      0U
#define SIFIVE_SPI_CSMODE_MODE_HOLD      2U
#define SIFIVE_SPI_CSMODE_MODE_OFF       3U

// inline void write_reg(uintptr_t addr, uint32_t value);
//inline uint32_t read_reg(uintptr_t addr);
//inline void spi_sendbyte(uint8_t byte);
//inline void waittx();
//inline void waitrx();
uint8_t spi_txrx(uint8_t byte);
uint8_t spi_dummy();
//inline uint8_t spi_readbyte();
//uint64_t spi_read64();
void spi_init();
void spi_set_clock(uint32_t clkin, uint32_t clkout);

static inline void write_reg(uintptr_t addr, uint32_t value) {
  volatile uint32_t * loc = (volatile uint32_t *) addr;
  *loc = value;
}

// Read a register
static inline uint32_t read_reg(uintptr_t addr) {
  return *(volatile uint32_t *) addr;
}

// Queues a single byte in the transfer fifo
static inline void spi_sendbyte(uint8_t byte) {
  // Write byte to transfer fifo
  write_reg(SPI_TXDATA, byte);
}

static inline void waittx() {
  while(!(read_reg(SPI_IP) & 1)) {}
}

static inline void waitrx() {
  while(read_reg(SPI_IP) & 2) {}
}

static inline uint8_t spi_readbyte() {
  return read_reg(SPI_RXDATA);
}

#endif
