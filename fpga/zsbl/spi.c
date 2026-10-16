///////////////////////////////////////////////////////////////////////
// spi.c
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: SPI Controller API for bootloader
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#include "spi.h"

uint8_t spi_txrx(uint8_t byte) {
  spi_sendbyte(byte);
  waitrx();
  return spi_readbyte();
}

uint8_t spi_dummy() {
  return spi_txrx(0xff);
}

uint64_t spi_read64() {
  uint64_t r;
  uint8_t rbyte;
  int i;

  for (i = 0; i < 8; i++) {
    spi_sendbyte(0xFF);
  }

  waittx();

  for (i = 0; i < 8; i++) {
    rbyte = spi_readbyte();
    r = r | (rbyte << ((8 - 1 - i)*8));
  }

  return r;
}

void spi_set_clock(uint32_t clkin, uint32_t clkout) {
  uint32_t div = (clkin/(2*clkout)) - 1;
  write_reg(SPI_SCKDIV, div);
}

// Initialize Sifive FU540 based SPI Controller
void spi_init() {
  // Enable interrupts
  write_reg(SPI_IE, 0x3);

  // Set TXMARK to 1. If the number of entries is < 1
  // IP's txwm field will go high.
  // Set RXMARK to 0. If the number of entries is > 0
  // IP's rwxm field will go high.
  write_reg(SPI_TXMARK, 1);
  write_reg(SPI_RXMARK, 0);

  // Set Delay 0 to default
  write_reg(SPI_DELAY0,
            SIFIVE_SPI_DELAY0_CSSCK(1) |
            SIFIVE_SPI_DELAY0_SCKCS(1));

  // Set Delay 1 to default
  write_reg(SPI_DELAY1,
            SIFIVE_SPI_DELAY1_INTERCS(1) |
            SIFIVE_SPI_DELAY1_INTERXFR(0));

  // Initialize the SPI controller clock to
  // div = (20MHz/(2*400kHz)) - 1 = 24 = 0x18
  write_reg(SPI_SCKDIV, 0x18);
}
