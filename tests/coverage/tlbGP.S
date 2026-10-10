///////////////////////////////////////////
// tlbGP.S
//
// Written: mmendozamanriquez@hmc.edu 4 April 2023
//          nlimpert@hmc.edu
//
// Purpose: Create Page tables and access gigapages
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate

#include "WALLY-init-lib.h"

# run-elf.bash find this in project description
main:
    # Page table root address at 0x80010000
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall
    li t5, 0
    li t0, 0xC0200000 // go to first gigapage
    li t4, 0x40000000 // put this outside the loop.
    li t2, 0      # i = 0
    li t3, 64     # Max amount of Loops = 16

loop: bge t2, t3, finished   # exit loop if i >= loops
    lw t1, 0(t0)
    li t1, 0x00008067 #load in jalr
    sw t1, 0(t0)
    fence.I
    jalr t0
    add t0, t0, t4
    addi t2, t2, 1
    j loop

finished:
    j done

.data

.align 16
# Page table situated at 0x80010000
pagetable:
    .8byte 0x20004401

.align 12
    .8byte 0x000000CF  //8000 0000
    .8byte 0x100000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF

    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF


    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
    .8byte 0x200000CF
