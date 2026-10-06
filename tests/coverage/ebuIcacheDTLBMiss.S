///////////////////////////////////////////
// ebu.S
//
// Written: Rose Thompson rose@rosethompson.net 4/29/2025
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

    # Page table root address at 0x80010000; SV39
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall

    #

#   Tricky case to cover.  I$ miss concurrent with DTLB miss.  HPTW has to hit the first
#   access in the cache and miss a later one.  Trigger this by doing a load that touches
#   a page not in the DTLB but where the top-level PTE is already there.  Has to happen
#   near the end of the 16-instruction I$ line.
#
#    Condition Coverage for instance /core/ebu/ebu/ebufsmarb --
#
#  File ../src/ebu/ebufsmarb.sv
#----------------Focused Condition View-------------------
#Line       72 Item    1  ((HREADY & FinalBeatD) & (LSUReq ~& IFUReq))
#Condition totals: 2 of 4 input terms covered = 50.00%
#
#  Input Term   Covered  Reason for no coverage   Hint
# -----------  --------  -----------------------  --------------
#      HREADY         Y
#  FinalBeatD         Y
#      LSUReq         N  '_1' not hit             Hit '_1'
#      IFUReq         N  No hits                  Hit '_0' and '_1'
#
#     Rows:       Hits  FEC Target            Non-masking condition(s)
# ---------  ---------  --------------------  -------------------------
#  Row   1:          2  HREADY_0              ((LSUReq ~& IFUReq) && FinalBeatD)
#  Row   2:         14  HREADY_1              ((LSUReq ~& IFUReq) && FinalBeatD)
#  Row   3:          1  FinalBeatD_0          ((LSUReq ~& IFUReq) && HREADY)
#  Row   4:         14  FinalBeatD_1          ((LSUReq ~& IFUReq) && HREADY)
#  Row   5:         14  LSUReq_0              ((HREADY & FinalBeatD) && IFUReq)
#  Row   6:    ***0***  LSUReq_1              ((HREADY & FinalBeatD) && IFUReq)
#  Row   7:    ***0***  IFUReq_0              ((HREADY & FinalBeatD) && LSUReq)
# Row   8:    ***0***  IFUReq_1              ((HREADY & FinalBeatD) && LSUReq)


    li a0, 0x80000000
    li a1, 0x81000000
    la a2, pagetableL1Target
    addi a2, a2, 0x40        # address of last level of the page table which needs to be removed from the data cache
    j label1

.align  6   # start on multiple of 64 bytes / 16 instruction cache line
label1:
    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    addi t2, t3, 0x10E  # occupy part of cache line
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    addi t2, t3, 0x10F  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    cbo.inval (a2)

    addi t2, t3, 0x100  # occupy part of cache line
    sfence.vma          # flush tlb
    lw t0, 0x234(a0)        # load to get an entry in the DTLB accessing top-level PTE
    addi t2, t3, 0x103  # occupy part of cache line
    addi t2, t3, 0x104  # occupy part of cache line
    addi t2, t3, 0x105  # occupy part of cache line
    addi t2, t3, 0x106  # occupy part of cache line
    addi t2, t3, 0x107  # occupy part of cache line
    addi t2, t3, 0x108  # occupy part of cache line
    addi t2, t3, 0x109  # occupy part of cache line
    addi t2, t3, 0x10A  # occupy part of cache line
    addi t2, t3, 0x10C  # occupy part of cache line
    addi t2, t3, 0x10D  # occupy part of cache line
    addi t2, t3, 0x10E  # occupy part of cache line
    addi t2, t3, 0x10F  # occupy part of cache line
    addi t2, t3, 0x110  # occupy part of cache line
    lw t0, 0x234(a1)        # trigger DTLB miss
    cbo.inval (a2)

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
pagetableL1Target:
    .8byte 0x00000000200000CF  # megapage
    .8byte 0x0000000020014C0F  # for VA starting at 80200000 (misaligned megapage)
    .8byte 0x0000000020005001  # for VA starting at 80400000 (bad PBMT pages)
    .8byte 0x4000000020004C01  # for VA starting at 80600000 (bad entry: nonleaf PTE can't have PBMT != 0)
    .8byte 0x0000000020005401  # for VA starting at 80800000 (testing rwx permissions with cbom/cboz)
    .8byte 0x00000000200000CF  # megapage
    .8byte 0x00000000200000CF  # megapage
    .8byte 0x00000000200000CF  # megapage
    .8byte 0x00000000200000CF  # megapage
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
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF

    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF

    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF

    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF
    .8byte 0xA0000000200020CF

    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF

    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF

    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF

    .8byte 0x80000000200060CF
    .8byte 0x80000000200060CF
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
