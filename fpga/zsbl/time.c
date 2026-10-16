///////////////////////////////////////////////////////////////////////
// time.c
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Gets and prints the current time.
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#include "time.h"
#include "boot.h"
#include "riscv.h"
#include "uart.h"

float getTime() {
  set_status_fs();
  float numCycles = (float)read_mcycle();
  float ret = numCycles/SYSTEMCLOCK;
  // clear_status_fs();
  return ret;
}

void print_time() {
  print_uart("[");
  set_status_fs();
  print_uart_float(getTime(),5);
  clear_status_fs();
  print_uart("] ");
}
