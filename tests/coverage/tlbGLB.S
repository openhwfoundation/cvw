///////////////////////////////////////////
// tlbGLB.S
//
// Written: mmendozamanriquez@hmc.edu 4 April 2023
//          nlimpert@hmc.edu
// Modified: kevin.j.thomas@okstate.edu May/4/20203
//
// Purpose: Coverage for the Page Table Entry Global flag check.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////


// load code to initialize stack, handle interrupts, terminate

#include "WALLY-init-lib.h"

# run-elf.bash find this in project description
main:
    # Page table root address at 0x80010000
    li t5, 0x9000000000080080 // try making asid = 0.
    csrw satp, t5

    # switch to supervisor mode
    li a0, 1
    ecall

    li t5, 0            # j = 0, run nASID only once
    li t3, 32                       //Max amount of Loops = 32
    li t4, 0x1000                   //offset between addresses.
    li t1, 0x00008067               //load in jalr x0 x1 0 instruction to be stored

setup:
    li t0, 0xC0000000               //starting address
    li t2, 0             # i = 0
    beq t5, zero, loop              //jump to first loop

loop2:  #jump to each of the addresses in different address space
    bge t2, t3, done
    jalr t0                         //jump to instruction at the virtual address
    add t0, t0, t4                  //change address for next loop
    addi t2, t2, 1                  //keep track of number of loops ran
    j loop2

loop:   #store jalr across memory
    bge t2, t3, nASID   # exit loop if i >= loops
    sw t1, 0(t0)                    //stores this jalr in the virtual address
    fence.I                         //invalidate instruction cache
    jalr t0                         //jump to instruction at the virtual address
    add t0, t0, t4                  //change address for next loop
    addi t2, t2, 1                  //keep track of number of loops ran
    j loop

nASID:   #swap to different address space -> jump to each address
    li a0, 3                        //swap to machine mode
    ecall
    li t5, 0x9000100000080080       //swap to address space 1 from 0
    csrw satp, t5
    li a0, 1                        // change back to supervisor mode.
    ecall
    li t5, 1                        //flag for finished after loops
    j setup



.data
.align 19
# level 3 Page table situated at 0x8008 0000, should point to 8008,1000
pagetable:
    .8byte 0x20020401

.align 12 // level 2 page table, contains direction to a gigapageg
    .8byte 0x0
    .8byte 0x0
    .8byte 0x200000EF // gigapage that starts at 8000 0000 goes to C000 0000
    .8byte 0x20020821 // pointer to next page table entry at 8008 2000

.align 12 // level 1 page table, points to level 0 page table
    .8byte 0x20020C21

.align 12 // level 0 page table, points to address C000 0000 // FOR NOW ALL OF THESE GO TO 8 instead of C cause they start with 2
    .8byte 0x200000EF // access xC000 0000
    .8byte 0x200004EF // access xC000 1000
    .8byte 0x200008EF // access xC000 2000
    .8byte 0x20000CEF // access xC000 3000

    .8byte 0x200010EF // access xC000 4000
    .8byte 0x200014EF
    .8byte 0x200018EF
    .8byte 0x20001CEF

    .8byte 0x200020EF // access xC000 8000
    .8byte 0x200024EF
    .8byte 0x200028EF
    .8byte 0x20002CEF

    .8byte 0x200030EF // access xC000 C000
    .8byte 0x200034EF
    .8byte 0x200038EF
    .8byte 0x20003CEF

    .8byte 0x200040EF // access xC001 0000
    .8byte 0x200044EF
    .8byte 0x200048EF
    .8byte 0x20004CEF

    .8byte 0x200050EF // access xC001 4000
    .8byte 0x200054EF
    .8byte 0x200058EF
    .8byte 0x20005CEF

    .8byte 0x200060EF // access xC001 8000
    .8byte 0x200064EF
    .8byte 0x200068EF
    .8byte 0x20006CEF

    .8byte 0x200070EF // access xC001 C000
    .8byte 0x200074eF
    .8byte 0x200078EF
    .8byte 0x20007CEF

    .8byte 0x200080EF // access xC002 0000
    .8byte 0x200084EF
    .8byte 0x200088EF
    .8byte 0x20008CEF

        .8byte 0x200010EF // access xC000 4000
    .8byte 0x200014EF
    .8byte 0x200018EF
    .8byte 0x20001CEF

    .8byte 0x200020EF // access xC000 8000
    .8byte 0x200024EF
    .8byte 0x200028EF
    .8byte 0x20002CEF

    .8byte 0x200030EF // access xC000 C000
    .8byte 0x200034EF
    .8byte 0x200038EF
    .8byte 0x20003CEF

    .8byte 0x200040EF // access xC001 0000
    .8byte 0x200044EF
    .8byte 0x200048EF
    .8byte 0x20004CEF

    .8byte 0x200050EF // access xC001 4000
    .8byte 0x200054EF
    .8byte 0x200058EF
    .8byte 0x20005CEF

    .8byte 0x200060EF // access xC001 8000
    .8byte 0x200064EF
    .8byte 0x200068EF
    .8byte 0x20006CEF

    .8byte 0x200070EF // access xC001 C000
    .8byte 0x200074eF
    .8byte 0x200078EF
    .8byte 0x20007CEF

    .8byte 0x200080EF // access xC002 0000
    .8byte 0x200084EF
    .8byte 0x200088EF
    .8byte 0x20008CEF
