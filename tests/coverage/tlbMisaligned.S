///////////////////////////////////////////
// tlbMisaligned.S
//
// Written: Rose Thompson rose@rosethompson.net
//
// Purpose: Create a page table with misaligned load and store access.  Checks TLB misses prevent misaligned load/store fault.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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
    li t5, 0x1
    slli t5, t5, 62
    ori t5, t5, 0xF0
    csrs menvcfg, t5  # menvcfg.PBMTE = 1, CBZE, CBCFE, CBIE all 1

    # Page table root address at 0x80010000
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall
    li t5, 0
    li t2, 0x1000
    li t0, 0x1000 // go to first gigapage
    li t4, 0x40000000 // put this outside the loop.

    lw t1, 1(t0) # load a misaligned aligned cached address
    li t1, 0x00008067 #load in jalr
    add t0, t0, t2 # go to the next page
    sw t1, 1(t0) # store to another misaligned cached address.

    add t0, t0, t2 # go to the next page
    lw t1, 1(t0) # load a misaligned aligned uncached address should fault
    add t0, t0, t2 # go to the next page
    sw t1, 1(t0) # store to another misaligned uncached address should fault.

    fence.I

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


.align 12
    .8byte 0x0000000020004C01
    //.8byte 0x000002008000F// ADD IN THE MEGAPAGE should 3 nibbles of zeros be removed?

.align 12
    #80000000
    .8byte 0x200000CF
    .8byte 0x200004CF  # first page
    .8byte 0x200008CF  # second page
    .8byte 0x2000000020000CCF  # 3rd page

    .8byte 0x20000000200010CF  # 4th page
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

    .8byte 0x2000A0CF
    .8byte 0x2000A4CF
    .8byte 0x2000A8CF
    .8byte 0x2000ACCF

    .8byte 0x2000B0CF
    .8byte 0x2000B4CF
    .8byte 0x2000B8CF
    .8byte 0x2000BCCF

    .8byte 0x2000C0CF
    .8byte 0x2000C4CF
    .8byte 0x2000C8CF
    .8byte 0x2000CCCF

    .8byte 0x2000D0CF
    .8byte 0x2000D4CF
