///////////////////////////////////////////
// tlbMP.S
//
// Written: mmendozamanriquez@hmc.edu 4 April 2023
//          nlimpert@hmc.edu
//
// Purpose: Test coverage for LSU
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

main:
    # Page table root address at 0x80010000
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall

    li t5, 0
    li t0, 0x84000000 // go to first megapage
    li t4, 0x200000 // put this outside the loop.
    li t2, 0      # i = 0
    li t3, 32     # Max amount of Loops = 16

loop: bge t2, t3, finished   # exit loop if i >= loops
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
    .8byte 0x0000000020004801
    .8byte 0x0000000020004801
    .8byte 0x0000000020004801


.align 12 // megapages starting at 8000 0000 going to 8480 0000  (32*2 MiB beyond that)

    .8byte 0x200000CF // access 8000,0000
    .8byte 0x200800CF // access 8020,0000
    .8byte 0x201000CF // acesss 8040,0000
    .8byte 0x201800CF // acesss 8060,0000

    .8byte 0x202000CF // access 8080,0000
    .8byte 0x202800CF // access 80A0,0000
    .8byte 0x203000CF // access 80C0,0000
    .8byte 0x203800CF // access 80E0,0000

    .8byte 0x204000CF // access 8100,0000
    .8byte 0x204800CF
    .8byte 0x205000CF
    .8byte 0x205800CF

    .8byte 0x206000CF // access 8180,0000
    .8byte 0x206800CF
    .8byte 0x207000CF
    .8byte 0x207800CF

    .8byte 0x208000CF // access 8200,0000
    .8byte 0x208800CF
    .8byte 0x209000CF
    .8byte 0x209800CF

    .8byte 0x20A000CF // access 8280,0000
    .8byte 0x20A800CF
    .8byte 0x20B000CF
    .8byte 0x20B800CF

    .8byte 0x20C000CF // access 8300,0000
    .8byte 0x20C800CF
    .8byte 0x20D000CF
    .8byte 0x20D800CF

    .8byte 0x20E000CF // access 8380,0000
    .8byte 0x20E800CF
    .8byte 0x20F000CF
    .8byte 0x20F800CF

    .8byte 0x200000CF // access 8000,0000 I AM REPEATING PTE TO SAVE TIME.
    .8byte 0x200800CF // access 8020,0000
    .8byte 0x201000CF // acesss 8040,0000
    .8byte 0x201800CF // acesss 8060,0000

    .8byte 0x202000CF // access 8080,0000
    .8byte 0x202800CF // access 80A0,0000
    .8byte 0x203000CF // access 80C0,0000
    .8byte 0x203800CF // access 80E0,0000

    .8byte 0x204000CF // access 8100,0000
    .8byte 0x204800CF
    .8byte 0x205000CF
    .8byte 0x205800CF

    .8byte 0x206000CF // access 8180,0000
    .8byte 0x206800CF
    .8byte 0x207000CF
    .8byte 0x207800CF

    .8byte 0x208000CF // access 8200,0000
    .8byte 0x208800CF
    .8byte 0x209000CF
    .8byte 0x209800CF

    .8byte 0x20A000CF // access 8280,0000
    .8byte 0x20A800CF
    .8byte 0x20B000CF
    .8byte 0x20B800CF

    .8byte 0x20C000CF // access 8300,0000
    .8byte 0x20C800CF
    .8byte 0x20D000CF
    .8byte 0x20D800CF

    .8byte 0x20E000CF // access 8380,0000
    .8byte 0x20E800CF
    .8byte 0x20F000CF
    .8byte 0x20F800CF

    .8byte 0x20004C01
     // Kilopage entry, for addresses from 8400, 0000 to 841F, FFFF
                      // point to ...

.align 12 // should start at 84000000
    .8byte 0x210000CF
    .8byte 0x210004CF
    .8byte 0x210008CF
    .8byte 0x21000CCF

    .8byte 0x210010CF
    .8byte 0x210014CF
    .8byte 0x210018CF
    .8byte 0x21001CCF

    .8byte 0x210020CF
    .8byte 0x210024CF
    .8byte 0x210028CF
    .8byte 0x21002CCF

    .8byte 0x210030CF
    .8byte 0x210034CF
    .8byte 0x210038CF
    .8byte 0x21003CCF

    .8byte 0x210040CF
    .8byte 0x210044CF
    .8byte 0x210048CF
    .8byte 0x21004CCF

    .8byte 0x210050CF
    .8byte 0x210054CF
    .8byte 0x210058CF
    .8byte 0x21005CCF

    .8byte 0x210060CF
    .8byte 0x210064CF
    .8byte 0x210068CF
    .8byte 0x21006CCF

    .8byte 0x210070CF
    .8byte 0x210074CF
    .8byte 0x210078CF
    .8byte 0x21007CCF
