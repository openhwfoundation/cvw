///////////////////////////////////////////
// misalignedStoreSpill.S
//
// Written: Rose Thompson rose@rosethompson.net 05 May 2025
//
// Purpose: Test coverage for EBU
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
    li t5, 0x1
    slli t5, t5, 62
    ori t5, t5, 0xF0
    csrs menvcfg, t5  # menvcfg.PBMTE = 1, CBZE, CBCFE, CBIE all 1

    # Page table root address at 0x80010000; SV48
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall



    li a0, 0x80000fff
    j label1

.align  6   # start on multiple of 64 bytes / 16 instruction cache line
label1:
        # test 1
    li t0, 0xdeadbeef01234567
    sfence.vma          # flush tlb
    sd t0, 0x0(a0)        # load to get an entry in the DTLB accessing top-level PTE

        # test 2
    li a1, 4096
    add a0, a0, a1
    sd t0, 0(a0)        # cause a store page fault to the second half of the access. mtval should be updated to the address of the second half.

    # wrap up
    li a0, 3 # switch back to machine mode because code at 0x80000000 may not have clean page table entry
    ecall
    j done


.data

.align 16
# root Page table situated at 0x80010000
pagetable:
    .8byte 0x20004401  # 0x00000000-0x80_00000000: PTE at 0x80011000 01 valid
    .8byte 0x000000000000100F # misaligned terapage at 0x80_00000000

# next page table at 0x80011000
.align 12
    .8byte 0x000000000000100F # misaligned gigapage at 0x00000000
    .8byte 0x0000000020005801 # PTE for pages at 0x40000000
    .8byte 0x0000000020004801 #


# Next page table at 0x80012000 for gigapage at 0x80000000
.align 12
    .8byte 0x0000000020004C01  # for VA starting at 80000000 (pointer to NAPOT 64 KiB pages)
    .8byte 0x0000000020014C0F  # for VA starting at 80200000 (misaligned megapage)
    .8byte 0x0000000020005001  # for VA starting at 80400000 (bad PBMT pages)
    .8byte 0x4000000020004C01  # for VA starting at 80600000 (bad entry: nonleaf PTE can't have PBMT != 0)
    .8byte 0x0000000020005401  # for VA starting at 80800000 (testing rwx permissions with cbom/cboz)
    .8byte 0x0000000020005801  # for VA starting at 80A00000 (pointer to NAPOT 64 KiB pages like at 80000000)
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01
    .8byte 0x0000000020004C01

# Leaf page table at 0x80013000 with NAPOT pages
.align 12
    #80000000
    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF
    .8byte 0x0000000000000000 # this is in invalid so that the second half of the access causes a fault
    .8byte 0x00000000200020CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF
    .8byte 0x00000000200020CF

    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF

    .8byte 0x80000000200060CF    # A
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF

    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF

    .8byte 0x80000000200060CF   # e0
    .8byte 0x00000000200060CF   # e8
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF

    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF

    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF

    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF

    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF
    .8byte 0x800000002000A0CF

    .8byte 0x800000002000E0CF
    .8byte 0x800000002000E0CF
    .8byte 0x800000002000E0CF
    .8byte 0x800000002000E0CF

    .8byte 0x800000002000E0CF
    .8byte 0x800000002000E0CF

# Leaf page table at 0x80014000 with PBMT pages
.align 12
    #80400000
    .8byte 0x60000000200020CF   # reserved entry

# Leaf page table at 0x80015000 with various permissions for testing CBOM and CBOZ
.align 12
    #80800000
    .8byte 0x00000000200000CF   # valid rwx for VA 80800000
    .8byte 0x00000000200000CB   # valid r x for VA 80801000
    .8byte 0x00000000200000C3   # valid r   for VA 80802000
    .8byte 0x00000000200000C9   # valid   x for VA 80803000
    .8byte 0x00000000200000CD   # valid  wx for VA 80804000 (illegal combination, but used to test tlbcontrol)
    .8byte 0x000000002000000F   # valid rwx for VA 80805000  for covering ITLB translate and UpdateDA
    .8byte 0x20000000200000CF   # PBMT=1    for VA 80806000  for covering ITLB BadPBMT

# Leaf page table at 0x80016000 with NAPOT pages
.align 12
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
