///////////////////////////////////////////
// hptwAccessFault.S
//
// Written: Rose Thompson rose@rosethompson.net
//
// Purpose: Force the HPTW to walk a page table with invalid addresses so that the pma checker
// generate access faults.
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

    # Page table root address at 0x80010000
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall
    li t5, 0
    li t2, 0x1000
    li t0, 0x8000001000

    lw t1, 0(t0)       # this load is a valid virtual address, but the page table will access an invalid address so it should cause a load access fault
    li t1, 0x00008067  # this store is a valid virtual address, but the page table will access an invalid address so it should cause a store access fault
    add t0, t0, t2
        sw t1, 0(t0)

        j jumppoint

jumppoint:
.align 6 # aligns to cache line size
        sw t1, 0(t0)
        sw t1, 4(t0)
        sw t1, 8(t0)
        sw t1, 12(t0)
        sw t1, 16(t0)
        sw t1, 20(t0)
        sw t1, 24(t0)
        sw t1, 28(t0)
        sw t1, 32(t0)
        sw t1, 36(t0)
        sw t1, 40(t0)
        sw t1, 44(t0)
        sw t1, 48(t0)
        sw t1, 52(t0) # this one causes a concurrent I$ miss with HPTW access exception (store access exception)
        sw t1, 56(t0)
        lw t3, 0(t0)
        lw t3, 4(t0)
        lw t3, 8(t0)
        lw t3, 12(t0)
        lw t3, 16(t0)

    fence.I

finished:
    j done

.data

.align 16
# Page table situated at 0x80010000
pagetable:
    .8byte 0x20004401
    .8byte 0x30004401  # point to invalid region of physical memory

.align 12
    .8byte 0x0000004020004801
    .8byte 0x0000000020004801
    .8byte 0x0000000020004801


.align 12
    .8byte 0x0000000020004C01

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
