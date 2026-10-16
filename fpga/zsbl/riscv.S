///////////////////////////////////////////////////////////////////////
// riscv.S
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Basic utility functions for reading registers
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

.section .text
.globl read_mcycle
.type read_mcycle, @function
read_mcycle:
    csrr a0, mcycle
    ret

.section .text
.globl get_ra
.type get_ra, @function
get_ra:
    mv a0, ra
    ret

.section .text
.globl set_status_fs
.type set_status_fs, @function
set_status_fs:
    lui t1, 0x6
    csrs mstatus, t1
    ret

.section .text
.globl clear_status_fs
.type clear_status_fs, @function
clear_status_fs:
    lui t1, 0x6
    csrc mstatus, t1
    ret
