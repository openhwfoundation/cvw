///////////////////////////////////////////////////////////////////////
// uart.h
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Header for the UART functions.
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
#include <stdint.h>
#include "riscv.h"
#include "time.h"

// UART register addresses
#define UART_BASE 0x10000000

#define UART_RBR UART_BASE + 0x00
#define UART_THR UART_BASE + 0x00
#define UART_IER UART_BASE + 0x01
#define UART_IIR UART_BASE + 0x02
#define UART_FCR UART_BASE + 0x02
#define UART_LCR UART_BASE + 0x03
#define UART_MCR UART_BASE + 0x04
#define UART_LSR UART_BASE + 0x05
#define UART_MSR UART_BASE + 0x06
#define UART_SCR UART_BASE + 0x07
#define UART_DLL UART_BASE + 0x00
#define UART_DLM UART_BASE + 0x01

// Primary function prototypes
void init_uart(uint32_t freq, uint32_t baud);
void write_reg_u8(uintptr_t addr, uint8_t value);
uint8_t read_reg_u8(uintptr_t addr);
int read_serial(uint8_t *res);
void print_uart(const char* str);
void print_uart_int(uint32_t addr);
void print_uart_dec(uint64_t addr);
void print_uart_addr(uint64_t addr);
void print_uart_hex(uint64_t addr, int n);
void print_uart_byte(uint8_t byte);
void print_uart_float(float num, int precision);
// void print_time();

// Print numbers in hex with specified widths
#define print_uart_int(addr) print_uart_hex(addr, 4)
#define print_uart_addr(addr) print_uart_hex(addr, 8)
#define print_uart_byte(addr) print_uart_hex(addr, 1)
#define print_r7(addr) print_uart_hex(addr, 5)
#define print_r1(addr) print_uart_byte(addr)

// Print line with numbers utility macros
#define println(msg) print_uart(msg "\r\n");
#define println_with_dec(msg, num) print_uart(msg); print_uart_dec(num); print_uart("\r\n")
#define println_with_byte(msg, num) print_uart(msg); print_uart_byte(num); print_uart("\r\n")
#define println_with_int(msg, num) print_uart(msg); print_uart_int(num); print_uart("\r\n")
#define println_with_addr(msg, num) print_uart(msg); print_uart_addr(num); print_uart("\r\n")
#define println_with_r1(msg, num) print_uart(msg); print_r1(num); print_uart("\r\n")
#define println_with_r7(msg, num) print_uart(msg); print_r7(num); print_uart("\r\n")
#define println_with_float(msg, num) print_uart(msg); set_status_fs(); print_uart_float(num,5); clear_status_fs(); print_uart("\r\n")

/* #define print_time() print_uart("["); \ */
/*   set_status_fs();                    \ */
/*   print_uart_float(getTime(),5);      \ */
/*   clear_status_fs();                  \ */
/*   print_uart("] ") */
