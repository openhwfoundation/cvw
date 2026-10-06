///////////////////////////////////////////
// nonleafpbmtfault.S
//
// Written: Rose Thompson rose@rosethompson.net
//
// Purpose: Force the HPTW to walk page tables with non-leaf PTEs that have nonzero bits in 63:54:
// N (63), each PBMT bit (62, 61), and each reserved bit (60:54) individually.  Each generates a
// load or store/amo page fault based on the original access type.
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

    lw t1, 0(t0)       # valid virtual address, valid physical address, but invalid PBMT in middle of page table.
    li t1, 0x00008067
    add t0, t0, t2
    sw t1, 0(t0)      # valid virtual address, valid physical address, but invalid PBMT in middle of page table.

    li t0, 0x8040000000
    lw t1, 0(t0)      # walk hits non-leaf PTE with N bit (63) set: load page fault
    sw t1, 0(t0)      # same PTE: store/amo page fault

    li t0, 0x80C0000000
    lw t1, 0(t0)      # non-leaf PTE with PBMT bit 61 set: load page fault
    li t0, 0x8100000000
    lw t1, 0(t0)      # non-leaf PTE with reserved bit 60 set: load page fault
    li t0, 0x8140000000
    lw t1, 0(t0)      # non-leaf PTE with reserved bit 59 set: load page fault
    li t0, 0x8180000000
    lw t1, 0(t0)      # non-leaf PTE with reserved bit 58 set: load page fault
    li t0, 0x81C0000000
    lw t1, 0(t0)      # non-leaf PTE with reserved bit 57 set: load page fault
    li t0, 0x8200000000
    lw t1, 0(t0)      # non-leaf PTE with reserved bit 56 set: load page fault
    li t0, 0x8240000000
    lw t1, 0(t0)      # non-leaf PTE with reserved bit 55 set: load page fault

    li t0, 0x80200000
    lw t1, 0(t0)      # walk hits non-leaf PTE with reserved bit (54) set: load page fault

    fence.I

finished:
    j done

.data

.align 16
# Page table situated at 0x80010000
pagetable:
    .8byte 0x20004401
    .8byte 0x20004401

.align 12
    .8byte 0x4000004020004801   # idx0: non-leaf with PBMT bit 62 set: faults
    .8byte 0x8000000020004801   # idx1: non-leaf with N bit (63) set: faults
    .8byte 0x0000000020004801   # idx2: valid non-leaf (used by code/data mappings)
    .8byte 0x2000000020004801   # idx3: non-leaf with PBMT bit 61 set: faults
    .8byte 0x1000000020004801   # idx4: non-leaf with reserved bit 60 set: faults
    .8byte 0x0800000020004801   # idx5: non-leaf with reserved bit 59 set: faults
    .8byte 0x0400000020004801   # idx6: non-leaf with reserved bit 58 set: faults
    .8byte 0x0200000020004801   # idx7: non-leaf with reserved bit 57 set: faults
    .8byte 0x0100000020004801   # idx8: non-leaf with reserved bit 56 set: faults
    .8byte 0x0080000020004801   # idx9: non-leaf with reserved bit 55 set: faults


.align 12
    .8byte 0x0000000020004C01
    .8byte 0x0040000020004C01   # non-leaf with reserved bit (54) set: faults

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
