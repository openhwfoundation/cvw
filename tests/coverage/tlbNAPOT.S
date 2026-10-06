///////////////////////////////////////////
// tlbNAPOT.S
//
// Written: mmendozamanriquez@hmc.edu 4 April 2023
//          nlimpert@hmc.edu
// Adapted David_Harris@hmc.edu 8/29/23 to exercise NAPOT huge pages
//
// Purpose: Test coverage for LSU NAPOT
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
    csrs menvcfg, t5
    # Page table root address at 0x80010000; SV48
    li t5, 0x9000000000080010
    csrw satp, t5

    # sfence.vma x0, x0

    # switch to supervisor mode
    li a0, 1
    ecall

    li t4, 0x200000   # address step size
    li a2, 0x80215240 # Test NAPOT pages
    jal a1, looptest
    li a2, 0xC0215240  # Test ill-formed NAPOT pages
    jal a1, looptest
    li a2, 0x40215240  # Test properly formed pages with 1 in PPN[3] that are not NAPOT
    jal a1, looptest
    li t4, 0x1000     # address step size
    li a2, 0x80216000 # Test NAPOT pages
    jal a1, looptest

    sfence.vma
    li t4, 0x200000   # address step size
    li a2, 0x80215240 # Test NAPOT pages
    jal a1, looptest
    li a2, 0xC0215240  # Test ill-formed NAPOT pages
    jal a1, looptest
    li a2, 0x40215240  # Test properly formed pages with 1 in PPN[3] that are not NAPOT
    jal a1, looptest

    li a0, 3 # switch back to machine mode because code at 0x80000000 may not have clean page table entry
    ecall
    j done

looptest:
    mv t0, a2       # base address
    li t2, 0        # i = 0
    li t3, 32     # Max amount of Loops = 32
    li t5, 0x8082 # return instruction opcode

loop: bge t2, t3, finished   # exit loop if i >= loops
    sw t5, 0(t0)   # store a return at this address to exercise DTLB
    lw t1, 0(t0)   # read it back
    fence.i    # synchronize with I$
    jal changetoipfhandler  # set up trap handler to return from instruction page fault if necessary
    jalr ra, t0 # jump to the return statement to exercise the ITLB
    jal changetodefaulthandler
    add t0, t0, t4
    addi t2, t2, 1
    j loop

finished:
    jr a1

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

.align 4                # trap handlers must be aligned to multiple of 4
ipf_handler:
    # Load trap handler stack pointer tp
    csrrw tp, mscratch, tp  # swap MSCRATCH and tp
    sd t0, 0(tp)        # Save t0 and t1 on the stack
    sd t1, -8(tp)
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

.data

.align 16
# root Page table situated at 0x80010000
pagetable:
    .8byte 0x20004401 // old page table was 200040 which just pointed to itself! wrong

# next page table at 0x80011000
.align 12
    .8byte 0x0000000000000000 # gigapage at 0x00000000
    .8byte 0x0000000020005801 # gigapage at 0x40000000 used for non-NAPOT with PPN bit 3 set
    .8byte 0x0000000020004801 # gigapage at 0x80000000 used for testing NAPOT huge pages
    .8byte 0x0000000020005001 # gigapage at 0xC0000000 mapped to ill-formed NAPOT with wrong PPN


# Next page table at 0x80012000 for gigapage at 0x80000000
.align 12
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

# Next page table at 0x80014000: mega-sized, pointing to malformed NAPOT  for gigapage at 0xC9000000
.align 12
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401
    .8byte 0x0000000020005401

# Leaf page table at 0x80015000 with malformed NAPOT pages (wrong PPN) starting at 0xC0000000
.align 12
    #80000000
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF

    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF
    .8byte 0x80000000200000CF


# Next page table at 0x80016000: mega-sized, pointing to properly formed PTE with 1 in PPN bit 3  for gigapage at 0x40000000
.align 12
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01
    .8byte 0x0000000020005C01

# Leaf page table at 0x80017000 with properly formed PTE with bit 4 of PPN set but no NAPOT
.align 12
    #80000000
    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF

    .8byte 0x00000000200020CF
    .8byte 0x00000000200060CF
    .8byte 0x000000002000A0CF
    .8byte 0x000000002000E0CF
