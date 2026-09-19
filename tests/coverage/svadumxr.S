///////////////////////////////////////////
// svadumxr.S
//
// Written: David_Harris@hmc.edu 19 September 2026
//
// Purpose: Test coverage for two page-table-walker paths that no other test reaches.
//
//          A load from an execute-only page with sstatus.MXR clear, on a DTLB miss: the walker
//          judges the leaf with
//            InvalidRead = ReadAccess & ~Readable & (~STATUS_MXR | ~Executable)
//          and only a page that is executable but not readable makes the MXR term decide the
//          outcome.  With MXR clear the load page-faults; with MXR set the same load is allowed.
//
//          A store that hits in the DTLB on a page whose D bit is clear, with Svadu enabled
//          (menvcfg.ADUE): the TLB reports that the entry needs its dirty bit set, and the LSU
//          starts the walker from a TLB hit rather than a miss to update the PTE in memory.  A
//          load brings the page in first, so the store cannot miss.
//
//          The first 2 MiB of RAM are identity-mapped with 4 KiB pages so the two data pages can
//          carry their own permissions while the code runs through the same table.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
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
#include "WALLY-selfcheck.h"

// address of the level-0 PTE that maps a label, into reg (clobbers t6)
.macro L0_ENTRY label, reg
    la \reg, \label
    srli \reg, \reg, 12
    andi \reg, \reg, 0x1FF
    slli \reg, \reg, 3
    la t6, l0table
    add \reg, \reg, t6
.endm

main:
    // Identity-map the first 2 MiB of RAM with 4 KiB pages (Sv39: root -> level 1 -> level 0)
    la t0, l0table
    li t1, 0x80000              # PPN of 0x80000000
    li t2, 512
build_l0:
    slli t3, t1, 10
    ori t3, t3, 0xCF            # V R W X A D
    sd t3, 0(t0)
    addi t0, t0, 8
    addi t1, t1, 1
    addi t2, t2, -1
    bnez t2, build_l0
    la t0, l1table
    la t1, l0table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1               # non-leaf
    sd t1, 0(t0)                # level-1 entry 0: VA 0x80000000-0x801FFFFF
    la t0, roottable
    la t1, l1table
    srli t1, t1, 12
    slli t1, t1, 10
    ori t1, t1, 1
    sd t1, 16(t0)               # root entry 2: VA 0x80000000-0xBFFFFFFF

    // xo_page is execute-only: clear R and W.  nd_page keeps every permission but has D clear.
    L0_ENTRY xo_page, t0
    ld t1, 0(t0)
    andi t1, t1, -7             # ~(R | W)
    sd t1, 0(t0)
    L0_ENTRY nd_page, t0
    ld t1, 0(t0)
    andi t1, t1, -129           # ~D
    sd t1, 0(t0)

    // Data for the loads below, written while translation is still off
    la a1, xo_page
    li t0, 0xFEEDFACECAFEBEEF
    sd t0, 0(a1)
    la a2, nd_page
    li t0, 0x0123456789ABCDEF
    sd t0, 0(a2)

    li t0, 1
    slli t0, t0, 61             # menvcfg.ADUE: hardware updates A and D
    csrs menvcfg, t0
    la t0, roottable
    srli t0, t0, 12
    li t1, 0x8000000000000000   # MODE = 8, Sv39
    or t0, t0, t1
    csrw satp, t0
    sfence.vma

    li a0, 1
    ecall                       # supervisor mode

    // MXR clear: the load from the execute-only page misses in the DTLB, the walker finds a leaf
    // that is readable only under MXR, and the load page-faults; the handler steps over it.
    li t1, 0
    ld t1, 0(a1)
    SC_CHECK_EQ t1, zero, 1     # the faulting load wrote nothing

    // MXR set: after an sfence.vma the same load misses again and is allowed this time
    li t0, 1
    slli t0, t0, 19             # sstatus.MXR
    csrs sstatus, t0
    sfence.vma
    ld t1, 0(a1)
    li t2, 0xFEEDFACECAFEBEEF
    SC_CHECK_EQ t1, t2, 2
    csrc sstatus, t0

    // D clear: the load fills the DTLB with the entry, then the store hits it and needs D set, so
    // the walker is started from a DTLB hit to update the PTE; the store then completes.
    ld t1, 0(a2)
    li t2, 0x0123456789ABCDEF
    SC_CHECK_EQ t1, t2, 3
    sd t1, 8(a2)
    ld t3, 8(a2)
    SC_CHECK_EQ t3, t2, 4
    L0_ENTRY nd_page, t0
    ld t1, 0(t0)
    andi t1, t1, 0x80           # D
    li t2, 0x80
    SC_CHECK_EQ t1, t2, 5       # the hardware set the dirty bit in memory

    li a0, 3
    ecall                       # machine mode
    csrw satp, zero
    sfence.vma
    SC_PASS
    j done

.data
.p2align 12
roottable:
    .fill 512, 8, 0
l1table:
    .fill 512, 8, 0
l0table:
    .fill 512, 8, 0
xo_page:
    .fill 512, 8, 0
nd_page:
    .fill 512, 8, 0
