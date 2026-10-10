///////////////////////////////////////////
// tlbNAPOT.S
//
// Written: mmendozamanriquez@hmc.edu 4 April 2023
//          nlimpert@hmc.edu
// Adapted David_Harris@hmc.edu 8/29/23 to exercise NAPOT huge pages
//
// Purpose: Test coverage for LSU NAPOT
//          Self-checking (WALLY-selfcheck.h).  Each looptest iteration stores "c.li a5, i; c.ret"
//          (i = the iteration) through its VA, loads it back, and runs it, so on the pages that
//          translate it checks that the load returns the word stored and that the fetch runs it
//          (a5 = i: the ITLB maps the VA to the physical page the DTLB stored into).  On the
//          ill-formed NAPOT pages (PPN[3:0] != 1000 with N = 1) the store, load and fetch must each
//          take a page fault (15, 13, 12) at the right instruction with mtval = the VA, and the load
//          and the code must not write their registers; rec_default and rec_ipf count the faults
//          that match (s9) and the ones that do not (s10), and every other trap but an ecall fails.
//          At the end, machine mode checks the physical pages: the 32 pages the 4 KiB step stored
//          into (0x80016000-0x80035000, through the NAPOT mappings of 0x80216000-0x80235000) and the
//          two pages the 2 MiB steps store into (0x80015240 through the NAPOT pages,
//          0x80018240 through the non-NAPOT pages).
//          Failure indices: 1 load value, 2 fetched code, 3/4 page faults matched/mismatched per
//          looptest call, 5 physical pages, 0xF0 any other trap.
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
// addresses that satp and the pointer PTEs name (0x80010000-0x80017FFF).
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

// The 4 KiB-step looptest call stores code at the start of every page from 0x80016000 to 0x80035000.
// That includes 0x80019000, where this code section starts, so keep its first word unused (and keep
// the code under 4 KiB so that no other page start in that range holds code).
.section .text.main
napot_pad:
    .word 0

#include "WALLY-selfcheck.h"

#define CLIRET 0x80824781               // "c.ret" << 16 | "c.li a5, 0"; c.li a5, i adds i << 2 for i = 0-31

// CALLTEST base, faults: run looptest from VA base; faults = 1 if every access there must page fault
.macro CALLTEST base, faults
    li a3, \faults
    li s9, 0
    li s10, 0
    li a2, \base
    jal a1, looptest
    li s7, 96 * \faults             # a store, load and fetch fault in each of 32 iterations
    SC_CHECK_EQ s9, s7, 3
    SC_CHECK_EQ s10, zero, 4
.endm

# run-elf.bash find this in project description
main:
    la t5, rec_default
    csrw mtvec, t5
    li s6, CLIRET
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
    CALLTEST 0x80215240, 0 # Test NAPOT pages
    CALLTEST 0xC0215240, 1 # Test ill-formed NAPOT pages
    CALLTEST 0x40215240, 0 # Test properly formed pages with 1 in PPN[3] that are not NAPOT
    li t4, 0x1000     # address step size
    CALLTEST 0x80216000, 0 # Test NAPOT pages

    sfence.vma
    li t4, 0x200000   # address step size
    CALLTEST 0x80215240, 0 # Test NAPOT pages
    CALLTEST 0xC0215240, 1 # Test ill-formed NAPOT pages
    CALLTEST 0x40215240, 0 # Test properly formed pages with 1 in PPN[3] that are not NAPOT

    li a0, 3 # switch back to machine mode because code at 0x80000000 may not have clean page table entry
    ecall

    # The physical pages hold the code each mapping stored: the 4 KiB step's 32 pages, and the last
    # iteration's code at the address that every 2 MiB step's VA maps to
    li t0, 0x80016000
    li t2, 0
    li t3, 32
1:  slli t5, t2, 2
    add t5, t5, s6
    lwu t1, 0(t0)
    SC_CHECK_EQ_ADR t1, t5, t0, 5
    li t5, 0x1000
    add t0, t0, t5
    addi t2, t2, 1
    blt t2, t3, 1b
    li t5, CLIRET + (31 << 2)
    li t0, 0x80015240
    lwu t1, 0(t0)
    SC_CHECK_EQ_ADR t1, t5, t0, 5
    li t0, 0x80018240
    lwu t1, 0(t0)
    SC_CHECK_EQ_ADR t1, t5, t0, 5

    SC_PASS
    j done

looptest:
    mv t0, a2       # base address
    li t2, 0        # i = 0
    li t3, 32     # Max amount of Loops = 32

loop: bge t2, t3, finished   # exit loop if i >= loops
    slli t5, t2, 2
    add t5, t5, s6  # "c.li a5, i; c.ret"
    li t1, -1
napot_sw:
    sw t5, 0(t0)   # store code at this address to exercise DTLB
napot_lw:
    lw t1, 0(t0)   # read it back
    fence.i    # synchronize with I$
    jal changetoipfhandler  # set up trap handler to return from instruction page fault if necessary
    li a5, -1
    jalr ra, t0 # jump to the code to exercise the ITLB
    jal changetodefaulthandler
    li s4, -1       # a faulting load and the code leave t1 and a5 alone
    mv s5, s4
    bnez a3, 1f
    addiw s4, t5, 0 # the load returns the word stored, sign-extended
    mv s5, t2       # the code sets a5 = i
1:  SC_CHECK_EQ_ADR t1, s4, t0, 1
    SC_CHECK_EQ_ADR a5, s5, t0, 2
    add t0, t0, t4
    addi t2, t2, 1
    j loop

finished:
    jr a1

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

// rec_default: mtvec while looptest's store and load run.  A store (15) or load (13) page fault must come from
// napot_sw / napot_lw with mtval = the VA in t0: count it in s9 if so and in s10 if not, then let the library
// handler skip the instruction.  Everything else goes to sc_trap_handler, which passes ecalls on to the library
// handler and fails the test on any other trap.  s7, s8 and s11 are the handlers' scratch registers.
.align 4
rec_default:
    csrr s7, mcause
    li s8, 13
    la s11, napot_lw
    beq s7, s8, 1f
    li s8, 15
    la s11, napot_sw
    beq s7, s8, 1f
    j sc_trap_handler
1:  csrr s7, mepc
    bne s7, s11, 2f
    csrr s7, mtval
    bne s7, t0, 2f
    addi s9, s9, 1
    j trap_handler
2:  addi s10, s10, 1
    j trap_handler

// rec_ipf: mtvec while looptest's jalr runs.  An instruction page fault (12) must have mepc = mtval = the VA in
// t0: count it, then ipf_handler returns to ra.  Everything else goes to sc_trap_handler.
.align 4
rec_ipf:
    csrr s7, mcause
    li s8, 12
    beq s7, s8, 1f
    j sc_trap_handler
1:  csrr s7, mepc
    bne s7, t0, 2f
    csrr s7, mtval
    bne s7, t0, 2f
    addi s9, s9, 1
    j ipf_handler
2:  addi s10, s10, 1
    j ipf_handler

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
