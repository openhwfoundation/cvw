///////////////////////////////////////////////////////////////////////
// fail.c
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Prints information on the uart when a fatal bug is
//          encountered. Will expand this later.
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#include "fail.h"
#include "uart.h"
#include "riscv.h"
#include "time.h"

void fail() {
  // Get address that led to failure
  register uint64_t addr;
  asm volatile ("mv %0, ra" : "=r"(addr) : : "memory");

  // Print message
  print_time();
  println_with_addr("Failed at: 0x", addr);

  // Loop forever
  while(1) {

  }
}
