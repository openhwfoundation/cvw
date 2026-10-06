///////////////////////////////////////////
// tlbASID.S
//
// Written: mmendozamanriquez@hmc.edu 4 April 2023
//          nlimpert@hmc.edu
//
// Purpose: Test coverage for IFU TLB camlines with mismatched ASID values. This file tests odd
// numbered camlines. tlbASID2.S covers even numbered tlb camlines. These two files are identical.
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

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall

    li t0, 0xC0000000

    li t2, 0            # i = 0
    li t5, 0            # j = 0 // now use as a counter for new asid loop
    li t3, 32           # Max amount of Loops = 32

loop: bge t2, t3, finished   # exit loop if i >= loops
    sfence.vma
    li t1, 0x00008067 #load in jalr
    sw t1, 0(t0)
    fence.I
    jalr t0
    li t5, 0x9001000000080080 // try making asid = 1
    csrw satp, t5
    jalr t0
    li t5, 0x9000000000080080 // try making asid = 0
    csrw satp, t5
    li t4, 0x1000
    add t0, t0, t4
    addi t2, t2, 1
    j loop

finished:
    j done

.data
.align 19
# level 3 Page table situated at 0x8008 0000, should point to 8008,1000
pagetable:
    .8byte 0x20020401

.align 12 // level 2 page table, contains direction to a gigapage
    .8byte 0x0
    .8byte 0x0
    .8byte 0x200000CF // gigapage that starts at 8000 0000 goes to C000 0000
    .8byte 0x20020801 // pointer to next page table entry at 8008 2000

.align 12 // level 1 page table, points to level 0 page table
    .8byte 0x20020C01

.align 12 // level 0 page table, points to address C000 0000 // FOR NOW ALL OF THESE GO TO 8 instead of C cause they start with 2
    .8byte 0x200000CF // access xC000 0000
    .8byte 0x200004CF // access xC000 1000
    .8byte 0x200008CF // access xC000 2000
    .8byte 0x20000CCF // access xC000 3000

    .8byte 0x200010CF // access xC000 4000
    .8byte 0x200014CF
    .8byte 0x200018CF
    .8byte 0x20001CCF

    .8byte 0x200020CF // access xC000 8000
    .8byte 0x200024CF
    .8byte 0x200028CF
    .8byte 0x20002CCF

    .8byte 0x200030CF // access xC000 C000
    .8byte 0x200034CF
    .8byte 0x200038CF
    .8byte 0x20003CCF

    .8byte 0x200040CF // access xC001 0000
    .8byte 0x200044CF
    .8byte 0x200048CF
    .8byte 0x20004CCF

    .8byte 0x200050CF // access xC001 4000
    .8byte 0x200054CF
    .8byte 0x200058CF
    .8byte 0x20005CCF

    .8byte 0x200060CF // access xC001 8000
    .8byte 0x200064CF
    .8byte 0x200068CF
    .8byte 0x20006CCF

    .8byte 0x200070CF // access xC001 C000
    .8byte 0x200074CF
    .8byte 0x200078CF
    .8byte 0x20007CCF

    .8byte 0x200080CF // access xC002 0000
    .8byte 0x200084CF
    .8byte 0x200088CF
    .8byte 0x20008CCF
