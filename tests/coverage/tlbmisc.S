///////////////////////////////////////////
// tlbmisc.S
//
// Written David_Harris@hmc.edu 1/1/24
//
// Purpose: Test coverage for other TLB issues
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

    # store ret instruction in case we jump to an address mapping to 80000000
    li t0, 0x80000000
    li t5, 0x8082 # return instruction opcode
    sw t5, 0(t0)
    fence.i

    # Test not being able to write illegal SATP mode
    li t5, 0xA000000000080010
    csrw satp, t5

    # Page table root address at 0x80010000; SV48
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall

    # Instruction fetch from misaligned pages
    jal changetoipfhandler  # set up trap handler to return from instruction page fault if necessary
    li t0, 0x8000000000
    jalr ra, t0 # jump misaligned terapage
    li t0, 0x00000000
    jalr ra, t0 # jump to misaligned gigapage
    li t0, 0x80200000
    jalr ra, t0 # jump to misaligned megapage
    li t0, 0x7FFFFFFF80000000
    jalr ra, t0 # jump to page with UpperBitsUnequal
    li t0, 0x8000000080C00000
    jalr ra, t0
    li t0, 0x000000080C00000
    jalr ra, t0 # jump to page with bad reserved bits 60:54 in PTE

    # test with ENVCFG_ADUE = 1: switch to machine mode, set ADUE, access page with A=0, clear ADUE,
    li a0, 3
    ecall       # switch to machine mode
    li t0, 1
    slli t0, t0, 61
    csrs menvcfg, t0 # set menvcfg.ADUE
    li a0, 1
    ecall       # switch back to supervisor mode
    li t0, 0x0000000080E00000
    jalr ra, t0 # jump to page without accessed bit yet set
    li a0, 3
    ecall       # switch to machine mode
    li t0, 1
    slli t0, t0, 61
    csrc menvcfg, t0 # clear menvcfg.ADUE
    li a0, 1
    ecall       # switch back to supervisor mode

     # exercise malformed PBMT pages

    # page has PBMT = 3 (reserved)
    li t0, 0x80400000
    lw t1, 0(t0)    # read from page
    sw t1, 0(t0)    # write to page
    jalr ra, t0     # jump to page

    # AMO at page has PBMT = 2 or 1 (uncached)
    li t0, 0x80401000
    li t1, 10
    amoadd.w t1, t1, (t0)

    la t2, SpecialPage
    li t0, 0x200000000  # an address to a specific 1 GiB page
    j ConcurrentICacheMissDTLBMiss

.align 6
ConcurrentICacheMissDTLBMiss:
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
    lw t1, 0(t0)

    # write a cacheline length (512 bits) to memory in uncached region
    li t0, 0x80401000
    cbo.zero (t0)

    # Nonleaf PTE has PBMT != 0     causes a page fault during page walking.  H
    li t0, 0x80600000
    lw t1, 0(t0)    # read from page
    sw t1, 0(t0)    # write to page
    jalr ra, t0     # jump to page

    sfence.vma

    li t0, 0x18000000000
    lw t1, 0(t0)    # read from page
    sw t1, 0(t0)    # write to page
    jalr ra, t0     # jump to page

    # jump to address for TLB miss to trigger HPTW to make access with DisableTranslation = 1, Translate = 0
    li t0, 0x80805000
    jalr ra, t0
    li t0, 0x80807000 # again, triggering setting access bit
    jalr ra, t0

    # atomic access to uncachable memory
    #li t0, 0x80806000
    #sd zero, 0(t0)
    #amoadd.w t1, t0, (t0)

    # Access page with R=0 W = 1
    li t0, 0x80804000
    li t1, 0x8067 # ret
    sw t1, 0(t0) # have something to return from
    jalr ra, t0

    # Good PBMT with menvcfg.PBMT = 1,
    li t0, 0x80806000
    jalr ra, t0

    # Good PBMT with menvcfg.PBMTE = 0
    li a0, 3
    ecall   # switch to machine mode
    li t5, 0x1
    slli t5, t5, 62
    csrc menvcfg, t5  # menvcfg.PBMTE = 0
    li a0, 1
    ecall   # switch back to supervisor mode
    sfence.vma  # synchronize TLB after changing menvcfg.PBMTE
    li t0, 0x80806000
    jalr ra, t0      # jump to page to exercise ITLB with PBMT !=0 when ENVCFG_PMTE=0

    # Load and AMO operation on page table entry that causes access fault
    li t0, 0x81000000
    lw t1, 0(t0)
    sfence.vma
    amoadd.w t0, t0, 0(t0)

    # Access fault on top level PTE
    li t0, 0x1000000000
    lw t1, 0(t0)

    # Bad PBMT on top level PTE
    li t0, 0x1800000000
    lw t1, 0(t0)

    # Access fault on megapage
    li t0, 0x81400000
    lw t1, 0(t0)

    # Access fault walking page tables at megapage level
    li t0, 0xC0000000
    lw t1, 0(t0)

    # AMO operation on page table entry that causes page fault due to malformed PBMT
    li t0, 0x81200000
    jalr t0          # Attempt to fetch instruction from address causing faulty page walk
    lw t1, 0(t0)
    sfence.vma
    amoadd.w t0, t0, 0(t0)

    # point top-level page table to an illegal address and verify it faults
    li t0, 0x9000000000070000 # trap handler at non-existing memory location
    csrw satp, t0 # should cause trap
    sfence.vma
    nop


    # change back to default trap handler after checking everything that might cause an instruction page fault
    jal changetodefaulthandler

    # uncachable AMO access
    li t0, 0x80401000  # PBMT sets as uncachable
    amoadd.w t0, t0, 0(t0)

    # exercise CBOM instructions with various permissions
    li t0, 0x80800000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80801000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80802000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80803000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80804000
    cbo.zero (t0)
    cbo.clean (t0)

    # set mstatus.MXR
    li a0, 3
    ecall
    li t0, 1
    slli t0, t0, 19
    csrs mstatus, t0 # mstatus.mxr = 1
    li a0, 1
    ecall

    # exercise CBOM again now that MXR is set
    li t0, 0x80800000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80801000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80802000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80803000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80804000
    cbo.zero (t0)
    cbo.clean (t0)

    # attempt read from read disabled, execute enabled PTE with MXR set
    li t0, 0x81600000
    lw t1, 0(t0)    # read from page

    # clear mstatus.MXR
    li a0, 3
    ecall
    li t0, 1
    slli t0, t0, 19
    csrc mstatus, t0 # mstatus.mxr = 1
    li a0, 1
    ecall




    # wrap up
    li a0, 3 # switch back to machine mode because code at 0x80000000 may not have clean page table entry
    ecall
    j done

backandforth:
    ret

changetoipfhandler:
    li a0, 3
    ecall       # switch to machine mode
    la a0, ipf_handler
    csrw mtvec, a0 # point to new handler
    li a0, 1
    ecall       # switch back to supervisor mode
    ret

changetodefaulthandler:
    li a0, 3
    ecall       # switch to machine mode
    la a0, trap_handler
    csrw mtvec, a0 # point to new handler
    li a0, 1
    ecall       # switch back to supervisor mode
    ret

instructionpagefaulthandler:
    csrw mepc, ra # go back to calling function
    mret

.align 4                # trap handlers must be aligned to multiple of 16
ipf_handler:
    # Load trap handler stack pointer tp
    csrrw tp, mscratch, tp  # swap MSCRATCH and tp
    sd t0, 0(tp)        # Save t0 and t1 on the stack
    sd t1, -8(tp)
    li t5, 0x9000000000080010
    csrw satp, t5       # make sure we are pointing to the root page table
    csrr t0, mcause     # Check the cause
    li t1, 8            # is it an ecall trap?
    andi t0, t0, 0xFC   # if CAUSE = 8, 9, or 11
    beq t0, t1, ecall   # yes, take ecall
    csrr t0, mcause
    li t1, 12           # is it an instruction page fault
    beq t0, t1, ipf     # yes, return to calling function
    j trap_return

ipf:
    csrw mepc, ra       # return to calling function
    ld t1, -8(tp)       # restore t1 and t0
    ld t0, 0(tp)
    csrrw tp, mscratch, tp  # restore tp
    mret                # return from trap

.align 4                # trap handlers must be aligned to multiple of 16
fixsatptraphandler:
    li t5, 0x9000000000080010   # fix satp entry to normal page table root
    csrw satp, t5
    mret

.data

.align 16
# root Page table situated at 0x80010000
pagetable:
    .8byte 0x20004401  # VA 0x00000000-0x7F_FFFFFFFF: PTE at 0x80011000 01 valid
    .8byte 0x00000000000010CF # misaligned terapage at 0x80_00000000
    .8byte 0x00000000000000CF # access fault terapage at 0x100_00000000
    .8byte 0x4000000020004401 # Bad PBMT at VA 0x180_00000000

# next page table at 0x80011000
.align 12
    .8byte 0x00000000000010CF # misaligned gigapage at 0x00000000
    .8byte 0x0000000020005801 # PTE for pages at 0x40000000 pointing to 0x80150000
    .8byte 0x0000000020004801 # gigapage at 0x80000000 pointing to 0x80120000
    .8byte 0x0000000000000001 # gigapage at VA 0xC0000000 causes access fault
    .8byte 0x0
    .8byte 0x0
    .8byte 0x0
    .8byte 0x0
SpecialPage:
    .8byte 0x00000000200000CF   # 0x2_0000_0000 1GiB page1


# Next page table at 0x80012000 for gigapage at 0x80000000
.align 12
    .8byte 0x0000000020004C01  # for VA starting at 80000000 (pointer to NAPOT 64 KiB pages Page table at 80013000)
    .8byte 0x0000000020014CCF  # for VA starting at 80200000 (misaligned megapage)
    .8byte 0x0000000020005001  # for VA starting at 80400000 (bad PBMT pages page table at 0x80014000)
    .8byte 0x4000000020004C01  # for VA starting at 80600000 (bad entry: nonleaf PTE can't have PBMT != 0)
    .8byte 0x0000000020005401  # for VA starting at 80800000 (testing rwx permissions with cbom/cboz . page table at 0x80015000)
    .8byte 0x0000000020004C01  # for VA starting at 80A00000 (pointer to NAPOT 64 KiB pages like at 80000000.  page table at 0x80013000)
    .8byte 0x0F00000020004CCF  # for VA starting at 80C00000 (bad reserved field in bits 60:54)
    .8byte 0x000000002000000F  # for VA starting at 80E00000 (megapage not dirty or accessed)
    .8byte 0x0000000000004C01  # for VA starting at 81000000 (nonleaf pointing to unimplemented memory causes access fault)
    .8byte 0x4000000020004C01  # for VA starting at 81200000 (nonleaf with PBMT nonzero causes page fault)
    .8byte 0x00000000000000CF  # for VA starting at 81400000 (megapage with access fault)
    .8byte 0x0000000020004C09  # for VA starting at 81600000 (executable and not readable)
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1
    .8byte 0x0000000020004CC1

# Leaf page table at 0x80013000 with 64 KiB NAPOT pages
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
    .8byte 0x60000000200020CF   # reserved entry             VA 80400000
    .8byte 0x40000000201000CF   # non-cache non-idempotent   VA 80401000

# Leaf page table at 0x80015000 with various permissions for testing CBOM and CBOZ
.align 12
    #80800000
    .8byte 0x00000000200000CF   # valid rwx for VA 80800000
    .8byte 0x00000000200000CB   # valid r x for VA 80801000
    .8byte 0x00000000200000C3   # valid r   for VA 80802000
    .8byte 0x00000000200000C9   # valid   x for VA 80803000
    .8byte 0x00000000200000CD   # valid  wx for VA 80804000 (illegal combination, but used to test tlbcontrol)
    .8byte 0x00000000200000CF   # valid rwx for VA 80805000  for covering ITLB translate
    .8byte 0x20000000200000CF   # PBMT=1    for VA 80806000  for covering ITLB BadPBMT
    .8byte 0x000000002000000F   # valid rwx for VA 80807000  for covering UpdateDA
