///////////////////////////////////////////////////////////////////////
// riscv.h
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Function prototypes for riscv utility functions
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

uint64_t read_mcycle();
uint64_t get_ra();
void set_status_fs();
void clear_status_fs();
