///////////////////////////////////////////
// tlbmisc.S
//
// Written David_Harris@hmc.edu 1/1/24
//
// Purpose: Test coverage for other TLB issues
//          Self-checking (WALLY-selfcheck.h).  rec_ipf and rec_default log mcause, mepc and mtval
//          of every trap but an ecall in traplog before the test's handlers act on it, and at the
//          end, in machine mode, the log must match expected_traps: each fault the test provokes
//          (misaligned superpages, VA extension, reserved bits, Svpbmt, A = 0, W without R, PTE
//          and page access faults, CBO permissions with and without MXR) has the expected cause,
//          instruction and mtval, and no other trap was taken.  The test also checks the values of
//          the accesses that translate: the load through the 1 GiB page at VA 0x2_0000_0000
//          returns the word stored at PA 0x80000000, the AMO through the Svpbmt IO page returns
//          the value placed at its physical address, cbo.zero through the IO page and through the
//          read-write-execute page zeroes the physical lines, Svadu sets A in the megapage PTE that
//          the fetch from 0x80E00000 used, and the fault at 0x80807000 leaves its A = 0 PTE alone.
//          Failure indices: 1 trap count, 2 trap log entry (address = log entry), 3-8 values.
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

// The page tables come before WALLY-selfcheck.h so that its data does not move them off the
// addresses that satp and the PTEs name (0x80010000-0x80015FFF).
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

#include "WALLY-selfcheck.h"

#define NTRAPS  42                      // traps expected (see expected_traps)
#define LOGMAX  64                      // traps logged; more are only counted
#define AMOINIT 0x5A5A1234              // at PA 0x80400000 for the AMO through the Svpbmt IO page

# run-elf.bash find this in project description
main:
    la t5, rec_default
    csrw mtvec, t5

    # give the word at PA 0x80400000 a known value in memory (not just in the D$), since the AMO
    # through the IO page reaches memory directly
    li t0, 0x80400000
    li t1, AMOINIT
    sw t1, 0(t0)
    cbo.flush (t0)

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
tm_lw_pbmt3:
    lw t1, 0(t0)    # read from page
tm_sw_pbmt3:
    sw t1, 0(t0)    # write to page
    jalr ra, t0     # jump to page

    # AMO at page has PBMT = 2 or 1 (uncached)
    li t0, 0x80401000
    li t1, 10
    amoadd.w s3, t1, (t0)   # s3 = old value (checked at the end)

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
    lw s2, 0(t0)    # s2 = word at PA 0x80000000 (checked at the end)

    # write a cacheline length (512 bits) to memory in uncached region
    li t0, 0x80401000
    cbo.zero (t0)

    # Nonleaf PTE has PBMT != 0     causes a page fault during page walking.  H
    li t0, 0x80600000
tm_lw_nlpbmt:
    lw t1, 0(t0)    # read from page
tm_sw_nlpbmt:
    sw t1, 0(t0)    # write to page
    jalr ra, t0     # jump to page

    sfence.vma

    li t0, 0x18000000000
tm_lw_toppbmt:
    lw t1, 0(t0)    # read from page
tm_sw_toppbmt:
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
tm_sw_wonly:
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
tm_lw_ptaf:
    lw t1, 0(t0)
    sfence.vma
tm_amo_ptaf:
    amoadd.w t0, t0, 0(t0)

    # Access fault on top level PTE
    li t0, 0x1000000000
tm_lw_top1:
    lw t1, 0(t0)

    # Bad PBMT on top level PTE
    li t0, 0x1800000000
tm_lw_top2:
    lw t1, 0(t0)

    # Access fault on megapage
    li t0, 0x81400000
tm_lw_megaaf:
    lw t1, 0(t0)

    # Access fault walking page tables at megapage level
    li t0, 0xC0000000
tm_lw_walkaf:
    lw t1, 0(t0)

    # AMO operation on page table entry that causes page fault due to malformed PBMT
    li t0, 0x81200000
    jalr t0          # Attempt to fetch instruction from address causing faulty page walk
tm_lw_nlpbmt2:
    lw t1, 0(t0)
    sfence.vma
tm_amo_nlpbmt2:
    amoadd.w t0, t0, 0(t0)

    # point top-level page table to an illegal address and verify it faults
    li t0, 0x9000000000070000 # trap handler at non-existing memory location
    csrw satp, t0 # should cause trap
    # Wally's ITLB still holds this code's translation, so sfence.vma is fetched and the next fetch,
    # which walks the new page table, takes the access fault.  (Walking for the sfence.vma fetch,
    # which would fault there instead, is also legal.)
    sfence.vma
tm_nop_badroot:
    nop


    # change back to default trap handler after checking everything that might cause an instruction page fault
    jal changetodefaulthandler

    # uncachable AMO access
    li t0, 0x80401000  # PBMT sets as uncachable
tm_amo_io:
    amoadd.w t0, t0, 0(t0)

    # exercise CBOM instructions with various permissions
    li t0, 0x80800000
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80801000
tm_cboz_rx:
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80802000
tm_cboz_r:
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80803000
tm_cboz_x:
    cbo.zero (t0)
tm_cboc_x:
    cbo.clean (t0)
    li t0, 0x80804000
tm_cboz_wx:
    cbo.zero (t0)
tm_cboc_wx:
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
tm_cboz_rx_mxr:
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80802000
tm_cboz_r_mxr:
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80803000
tm_cboz_x_mxr:
    cbo.zero (t0)
    cbo.clean (t0)
    li t0, 0x80804000
tm_cboz_wx_mxr:
    cbo.zero (t0)
tm_cboc_wx_mxr:
    cbo.clean (t0)

    # attempt read from read disabled, execute enabled PTE with MXR set
    li t0, 0x81600000
tm_lw_xonly:
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

    ////////////////////////////////////////////////////////////////////////////////////////////
    // Checks, in machine mode
    ////////////////////////////////////////////////////////////////////////////////////////////
    // Every trap but an ecall matched expected_traps, in order
    la a1, traplog
    ld t2, 0(a1)
    li t3, NTRAPS
    SC_CHECK_EQ t2, t3, 1
    addi a1, a1, 8
    la a2, expected_traps
    li a3, 3 * NTRAPS
1:  ld t2, 0(a1)
    ld t3, 0(a2)
    SC_CHECK_EQ_ADR t2, t3, a1, 2
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    bnez a3, 1b
    // The load through the 1 GiB page at VA 0x2_0000_0000 read PA 0x80000000, which held c.ret then
    li t3, 0x8082
    SC_CHECK_EQ s2, t3, 3
    // The AMO through the Svpbmt IO page at VA 0x80401000 read PA 0x80400000
    li t3, AMOINIT
    SC_CHECK_EQ s3, t3, 4
    // cbo.zero through the IO page zeroed the line at PA 0x80400000 in memory, and cbo.zero through
    // the read-write-execute page at VA 0x80800000 zeroed the line at PA 0x80000000
    li a1, 0x80400000
    li a2, 0x80000000
    li a3, 8
2:  ld t2, 0(a1)
    SC_CHECK_EQ_ADR t2, zero, a1, 5
    ld t2, 0(a2)
    SC_CHECK_EQ_ADR t2, zero, a2, 6
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    bnez a3, 2b
    // Svadu set A in the megapage PTE of VA 0x80E00000 (level-1 table at 0x80012000, entry 7)
    li a1, 0x80012038
    ld t2, 0(a1)
    li t3, 0x000000002000004F
    SC_CHECK_EQ_ADR t2, t3, a1, 7
    // The fetch from VA 0x80807000 with ADUE = 0 faulted and left A = 0 (leaf table at 0x80015000, entry 7)
    li a1, 0x80015038
    ld t2, 0(a1)
    li t3, 0x000000002000000F
    SC_CHECK_EQ_ADR t2, t3, a1, 8

    SC_PASS
    j done

backandforth:
    ret

changetoipfhandler:
    li a0, 3
    ecall       # switch to machine mode
    la a0, rec_ipf
    csrw mtvec, a0 # point to new handler
    li a0, 1
    ecall       # switch back to supervisor mode
    ret

changetodefaulthandler:
    li a0, 3
    ecall       # switch to machine mode
    la a0, rec_default
    csrw mtvec, a0 # point to new handler
    li a0, 1
    ecall       # switch back to supervisor mode
    ret

instructionpagefaulthandler:
    csrw mepc, ra # go back to calling function
    mret

// REC_TRAP target: log mcause, mepc and mtval of a trap other than an ecall in traplog (the first LOGMAX
// of them; all are counted), then go on to the test's handler, target, with every register unchanged
.macro REC_TRAP target
    csrrw t0, mscratch, t0      # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    csrr t1, mcause
    li t2, 8                    # ecall from U, S or M: not logged
    beq t1, t2, 2f
    li t2, 9
    beq t1, t2, 2f
    li t2, 11
    beq t1, t2, 2f
    la t2, traplog
    ld t3, 0(t2)
    addi t3, t3, 1
    sd t3, 0(t2)                # count every trap
    li t1, LOGMAX
    bgtu t3, t1, 2f             # log the first LOGMAX
    slli t1, t3, 4
    slli t3, t3, 3
    add t1, t1, t3
    add t1, t1, t2              # traplog + 24 * count: entry count - 1 starts at -16(t1)
    csrr t3, mcause
    sd t3, -16(t1)
    csrr t3, mepc
    sd t3, -8(t1)
    csrr t3, mtval
    sd t3, 0(t1)
2:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0      # restore t0 and the trap stack pointer
    j \target
.endm

.align 4                # trap handlers must be aligned to multiple of 16
rec_ipf:                # mtvec while ipf_handler is selected
    REC_TRAP ipf_handler

.align 4
rec_default:            # mtvec while the library handler is selected
    REC_TRAP trap_handler

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
.align 12               // a page of its own, clear of the page tables above
traplog:                // number of traps but ecalls, then mcause, mepc, mtval of each
    .fill 1 + 3 * LOGMAX, 8, 0

// mcause, mepc, mtval of each trap but an ecall, in order
expected_traps:
    // instruction page faults: misaligned terapage, gigapage, megapage; VA extension (2); reserved PTE bits
    .dword 12, 0x8000000000, 0x8000000000
    .dword 12, 0x0, 0x0
    .dword 12, 0x80200000, 0x80200000
    .dword 12, 0x7FFFFFFF80000000, 0x7FFFFFFF80000000
    .dword 12, 0x8000000080C00000, 0x8000000080C00000
    .dword 12, 0x80C00000, 0x80C00000
    // leaf with PBMT = 3: load, store and fetch page faults
    .dword 13, tm_lw_pbmt3, 0x80400000
    .dword 15, tm_sw_pbmt3, 0x80400000
    .dword 12, 0x80400000, 0x80400000
    // nonleaf PTE with PBMT != 0 at level 1, then at the top level
    .dword 13, tm_lw_nlpbmt, 0x80600000
    .dword 15, tm_sw_nlpbmt, 0x80600000
    .dword 12, 0x80600000, 0x80600000
    .dword 13, tm_lw_toppbmt, 0x18000000000
    .dword 15, tm_sw_toppbmt, 0x18000000000
    .dword 12, 0x18000000000, 0x18000000000
    // fetch from a page with A = 0 and ADUE = 0
    .dword 12, 0x80807000, 0x80807000
    // W without R: store and fetch page faults
    .dword 15, tm_sw_wonly, 0x80804000
    .dword 12, 0x80804000, 0x80804000
    // PBMT = 1 with menvcfg.PBMTE = 0
    .dword 12, 0x80806000, 0x80806000
    // nonleaf PTE pointing to unimplemented memory: load and AMO access faults
    .dword 5, tm_lw_ptaf, 0x81000000
    .dword 7, tm_amo_ptaf, 0x81000000
    // invalid PTEs below VA 0x1000000000 and 0x1800000000: load page faults
    .dword 13, tm_lw_top1, 0x1000000000
    .dword 13, tm_lw_top2, 0x1800000000
    // megapage at PA 0: load access fault; level-1 pointer to PA 0: access fault on the walk
    .dword 5, tm_lw_megaaf, 0x81400000
    .dword 5, tm_lw_walkaf, 0xC0000000
    // nonleaf PTE with PBMT != 0: fetch, load and AMO page faults
    .dword 12, 0x81200000, 0x81200000
    .dword 13, tm_lw_nlpbmt2, 0x81200000
    .dword 15, tm_amo_nlpbmt2, 0x81200000
    // root page table in unimplemented memory: instruction access fault on the walk
    .dword 1, tm_nop_badroot, tm_nop_badroot
    // AMO to the IO page now that PBMTE = 0
    .dword 15, tm_amo_io, 0x80401000
    // CBOs: cbo.zero needs W; cbo.clean needs R (or X with MXR); W without R is reserved
    .dword 15, tm_cboz_rx, 0x80801000
    .dword 15, tm_cboz_r, 0x80802000
    .dword 15, tm_cboz_x, 0x80803000
    .dword 15, tm_cboc_x, 0x80803000
    .dword 15, tm_cboz_wx, 0x80804000
    .dword 15, tm_cboc_wx, 0x80804000
    // the same with MXR = 1, where cbo.clean of the execute-only page succeeds
    .dword 15, tm_cboz_rx_mxr, 0x80801000
    .dword 15, tm_cboz_r_mxr, 0x80802000
    .dword 15, tm_cboz_x_mxr, 0x80803000
    .dword 15, tm_cboz_wx_mxr, 0x80804000
    .dword 15, tm_cboc_wx_mxr, 0x80804000
    // load from an execute-only misaligned megapage
    .dword 13, tm_lw_xonly, 0x81600000
