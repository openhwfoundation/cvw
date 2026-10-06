///////////////////////////////////////////
// ifuCamlineWrite.S
//
// Written: Miles Cook <mdcook@g.hmc.edu> and Kevin Box <kbox@g.hmc.edu> 4/17
//
// Acknowledgements: The pagetable and outline for this test was written by Manuel Mendoza
//                   and Noah Limpert.
//
// Purpose: Test coverage for TLBCamlines in IFU
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
    li t5, 0x9000000000080010
    csrw satp, t5

    # switch to supervisor mode
    li a0, 1
    ecall

    li t0, 0x80015000 # base addr

    li t2, 0       # i = 0
    li t3, 33     # Max amount of Loops = 32

loop: bge t2, t3, finished   # exit loop if i >= loops
    li t4, 0x1000
    li t1, 0x00008067 # load in jalr
    sw t1, 0 (t0)
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
    .8byte 0x20004401 // old page table was 200040 which just pointed to itself! wrong

.align 12
    .8byte 0x0000000000000000
    .8byte 0x0000000020004801
    .8byte 0x0000000020004801


.align 12
    .8byte 0x0000000020004C01
    //.8byte 0x00000200800CF// ADD IN THE MEGAPAGE should 3 nibbles of zeros be removed?

.align 12
    #80000000
    .8byte 0x200000CF
    .8byte 0x200004CF
    .8byte 0x200008CF
    .8byte 0x20000CCF

    .8byte 0x200010CF
    .8byte 0x200014CF
    .8byte 0x200018CF
    .8byte 0x20001CCF

    .8byte 0x200020CF
    .8byte 0x200024CF
    .8byte 0x200028CF
    .8byte 0x20002CCF

    .8byte 0x200030CF
    .8byte 0x200034CF
    .8byte 0x200038CF
    .8byte 0x20003CCF

    .8byte 0x200040CF
    .8byte 0x200044CF
    .8byte 0x200048CF
    .8byte 0x20004CCF

    .8byte 0x200050CF
    .8byte 0x200054CF
    .8byte 0x200058CF
    .8byte 0x20005CCF

    .8byte 0x200060CF
    .8byte 0x200064CF
    .8byte 0x200068CF
    .8byte 0x20006CCF

    .8byte 0x200070CF
    .8byte 0x200074CF
    .8byte 0x200078CF
    .8byte 0x20007CCF

    .8byte 0x200080CF
    .8byte 0x200084CF
    .8byte 0x200088CF
    .8byte 0x20008CCF

    .8byte 0x200090CF
    .8byte 0x200094CF
    .8byte 0x200098CF
    .8byte 0x20009CCF

    .8byte 0x200100CF
    .8byte 0x200104CF
    .8byte 0x200108CF
    .8byte 0x20010CCF

    .8byte 0x200110CF
    .8byte 0x200114CF
    .8byte 0x200118CF
    .8byte 0x20011CCF

    .8byte 0x200120CF
    .8byte 0x200124CF
    .8byte 0x200128CF
    .8byte 0x20012CCF

    .8byte 0x200130CF
    .8byte 0x200134CF
