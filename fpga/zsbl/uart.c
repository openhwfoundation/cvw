///////////////////////////////////////////////////////////////////////
// uart.c
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Uart printing functions, as well as functions for printing
//          hex, decimal, and floating point numbers.
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#include "uart.h"

void write_reg_u8(uintptr_t addr, uint8_t value)
{
  volatile uint8_t *loc_addr = (volatile uint8_t *)addr;
  *loc_addr = value;
}

uint8_t read_reg_u8(uintptr_t addr)
{
  return *(volatile uint8_t *)addr;
}

int is_transmit_empty()
{
  return read_reg_u8(UART_LSR) & 0x20;
}

int is_receive_empty()
{
  return !(read_reg_u8(UART_LSR) & 0x1);
}

void write_serial(char a)
{
  while (is_transmit_empty() == 0) {};

  write_reg_u8(UART_THR, a);
}

void init_uart(uint32_t freq, uint32_t baud)
{
  // Alternative divisor calculation. From OpenSBI code.
  // Reduces error for every possible frequency.
  uint32_t divisor = (freq + 8 * baud) /(baud << 4);

  write_reg_u8(UART_IER, 0x00);                   // Disable all interrupts
  write_reg_u8(UART_LCR, 0x80);                   // Enable DLAB (set baud rate divisor)
  write_reg_u8(UART_DLL, divisor & 0xFF);         // divisor (lo byte)
  write_reg_u8(UART_DLM, (divisor >> 8) & 0xFF);  // divisor (hi byte)
  write_reg_u8(UART_LCR, 0x03);                   // 8 bits, no parity, one stop bit
  write_reg_u8(UART_FCR, 0xC7);                   // Enable FIFO, clear them, with 14-byte threshold
}

void print_uart(const char *str)
{
  const char *cur = &str[0];
  while (*cur != '\0') {
    write_serial((uint8_t)*cur);
    ++cur;
  }
}

uint8_t bin_to_hex_table[16] = {
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

void bin_to_hex(uint8_t inp, uint8_t res[2])
{
  res[1] = bin_to_hex_table[inp & 0xf];
  res[0] = bin_to_hex_table[(inp >> 4) & 0xf];
  return;
}

void print_uart_hex(uint64_t addr, int n)
{
  int i;
  for (i = n - 1; i > -1; i--) {
    uint8_t cur = (addr >> (i * 8)) & 0xff;
    uint8_t hex[2];
    bin_to_hex(cur, hex);
    write_serial(hex[0]);
    write_serial(hex[1]);
  }
}

void print_uart_dec(uint64_t addr) {

  // floor(log(2^64)) = 19
  char str[19] = {'\0'};
  uint8_t length = 1;

  uint64_t cur = addr;
  while (cur != 0) {
    char digit = bin_to_hex_table[cur % 10];
    // write_serial(digit);
    str[length] = digit;
    cur = cur/10;
    length++;
  }

  for (int i = length; i > -1; i--) {
    write_serial(str[i]);
  }
}

// Print a floating point number on the UART
void print_uart_float(float num, int precision) {
  char str[32] = {'\0'};
  char digit;
  uint8_t length = precision + 1;
  int i;
  uint64_t cur;

  str[precision] = '.';

  int pow = 1;

  // Calculate power for precision
  for (i = 0; i < precision; i++) {
    pow = pow * 10;
  }

  cur = (uint64_t)(num * pow);
  for (i = 0; i < precision; i++) {
    digit = bin_to_hex_table[cur % 10];
    str[i] = digit;
    cur = cur / 10;
  }

  cur = (uint64_t)num;
  do {
    digit = bin_to_hex_table[cur % 10];
    str[length] = digit;
    cur = cur/10;
    length++;
  } while (cur != 0);

  for (i = length; i > -1; i--) {
    write_serial(str[i]);
  }
}

/* void print_uart_int(uint32_t addr) */
/* { */
/*   int i; */
/*   for (i = 3; i > -1; i--)  { */
/*     uint8_t cur = (addr >> (i * 8)) & 0xff; */
/*     uint8_t hex[2]; */
/*     bin_to_hex(cur, hex); */
/*     write_serial(hex[0]); */
/*     write_serial(hex[1]); */
/*   } */
/* } */

/* void print_uart_addr(uint64_t addr) */
/* { */
/*   int i; */
/*   for (i = 7; i > -1; i--) { */
/*     uint8_t cur = (addr >> (i * 8)) & 0xff; */
/*     uint8_t hex[2]; */
/*     bin_to_hex(cur, hex); */
/*     write_serial(hex[0]); */
/*     write_serial(hex[1]); */
/*   } */
/* } */

/* void print_uart_byte(uint8_t byte) */
/* { */
/*   uint8_t hex[2]; */
/*   bin_to_hex(byte, hex); */
/*   write_serial(hex[0]); */
/*   write_serial(hex[1]); */
/* } */
