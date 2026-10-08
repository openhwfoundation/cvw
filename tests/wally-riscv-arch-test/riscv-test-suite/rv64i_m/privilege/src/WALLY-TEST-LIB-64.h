///////////////////////////////////////////
//
// WALLY-TEST-LIB-64.S
//
// Author: Kip Macsai-Goren <kmacsaigoren@g.hmc.edu>
//
// Created 2021-07-19
//
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

#include "model_test.h"
#include "arch_test.h"

.macro INIT_TESTS

// RVTEST_ISA("RV64I")

.section .text.init
.globl rvtest_entry_point
rvtest_entry_point:
RVMODEL_BOOT
RVTEST_CODE_BEGIN



    // ---------------------------------------------------------------------------------------------
    // Initialization Overview:
    //
    //   Initialize t1 as a virtual pointer to the test results
    //   Initialize a6 as a physical pointer to the test results
    //   Set up stack pointer, mscratch, sscratch
    //
    // ---------------------------------------------------------------------------------------------

    // address for test results
    la t1, test_1_res
    la a6, test_1_res // a6 reserved for the physical address equivalent of t1 to be used in trap handlers
                        // any time either is used, both must be updated.

    // address for normal user stack, mscratch stack, and sscratch stack
    la sp, mscratch_top
    csrw mscratch, sp
    la sp, sscratch_top
    csrw sscratch, sp
    la sp, stack_top

    // set up PMP so user and supervisor mode can access full address space
    csrw pmpcfg0, 0xF   # configure PMP0 to TOR RWX
    li t0, 0xFFFFFFFF
    csrw pmpaddr0, t0   # configure PMP0 top of range to 0xFFFFFFFF to allow all 32-bit addresses

.endm

// Code to trigger traps goes here so we have consistent mtvals for instruction addresses
// Even if more tests are added.
.macro CAUSE_TRAP_TRIGGERS
j end_trap_triggers

// The following tests involve causing many of the interrupts and exceptions that are easily done in a few lines
//      This effectively includes everything that isn't to do with page faults (virtual memory)
//
//      INPUTS: a3 (x13): the number of times one of the infinitely looping interrupt causes should loop before giving up and continuing without the interrupt firing.
//
cause_instr_addr_misaligned:
    // cause a misaligned address trap
    auipc t3, 0      // get current PC, which is aligned
    addi t3, t3, 0x2  // add 2 to pc to create misaligned address (Assumes compressed instructions are disabled)
    jr t3 // cause instruction address midaligned trap
    ret

cause_instr_access:
    sd ra, -8(sp) // push the return address onto the stack
    addi sp, sp, -8
    jalr zero // cause instruction access trap (address zero is an address with no memory)
    ld ra, 0(sp) // pop return address back from the stack
    addi sp, sp, 8
    ret

cause_illegal_instr:
    .word 0xFFFFFFFF // 32 bit 1s is an illegal instruction
    ret

cause_breakpnt:
    ebreak
    ret

cause_load_addr_misaligned:
    li t3, 0x02000000 // base address of clint, because with zicclsm misaligned cached access won't trap
    //auipc t3, 0      // get current PC, which is aligned
    addi t3, t3, 1
    lw t4, 0(t3)    // load from a misaligned address
    ret

cause_load_acc:
    lw t4, 0(zero)    // load from unimplemented address ( zero)
    ret

cause_store_addr_misaligned:
    li t3, 0x02000000 // base address of clint, because with zicclsm misaligned cached access won't trap
    //auipc t3, 0      // get current PC, which is aligned
    addi t3, t3, 1
    sw t4, 0(t3)     // store to a misaligned address
    ret

cause_store_acc:
    sw t4, 0(zero)     // store to unimplemented address (zero)
    ret

cause_ecall:
    // ASSUMES you have already gone to the mode you need to call this from.
    ecall
    ret

cause_m_time_interrupt:
    // The following code works for both RV32 and RV64.
    // RV64 alone would be easier using double-word adds and stores
    li t3, 0x30          // Desired offset from the present time
    mv a3, t3            // copy value in to know to stop waiting for interrupt after this many cycles
    la t4, 0x02004000    // MTIMECMP register in CLINT
    la t5, 0x0200BFF8    // MTIME register in CLINT
    lw t2, 0(t5)         // low word of MTIME
    lw t6, 4(t5)         // high word of MTIME
    add t3, t2, t3       // add desired offset to the current time
    bgtu t3, t2, nowrap_m  // check new time exceeds current time (no wraparound)
    addi t6, t6, 1       // if wrap, increment most significant word
nowrap_m:
    sw t6,4(t4)          // store into most significant word of MTIMECMP
    sw t3, 0(t4)         // store into least significant word of MTIMECMP
time_loop_m:
    addi a3, a3, -1
    bnez a3, time_loop_m // go through this loop for [a3 value] iterations before returning without performing interrupt
    ret

cause_s_time_interrupt:
    li t3, 0x30          // Desired offset from the present time
    mv a3, t3            // copy value in to know to stop waiting for interrupt after this many cycles
    // la t4, 0x02004000    // MTIMECMP register in CLINT
    la t5, 0x0200BFF8    // MTIME register in CLINT *** we still read from mtime since stimecmp is compared to it
    lw t2, 0(t5)         // low word of MTIME
    lw t6, 4(t5)         // high word of MTIME
    add t3, t2, t3       // add desired offset to the current time
    csrw stimecmp, t3     // store into most significant word of STIMECMP
time_loop_s:
    addi a3, a3, -1
    bnez a3, time_loop_s // go through this loop for [a3 value] iterations before returning without performing interrupt
    ret

cause_m_soft_interrupt:
    la t3, 0x02000000      // MSIP register in CLINT
    li t4, 1               // 1 in the lsb
    sw t4, 0(t3)          // Write MSIP bit
    ret

cause_s_soft_interrupt:
    li t3, 0x2
    csrs sip, t3 // set supervisor software interrupt pending. SIP is a subset of MIP, so writing this should also change MIP.
    ret

cause_s_soft_from_m_interrupt:
    li t3, 0x2
    csrs mip, t3 // set supervisor software interrupt pending. SIP is a subset of MIP, so writing this should also change MIP.
    ret

cause_m_ext_interrupt:
    // ========== Configure PLIC ==========
    li a3, 0x40
    // m priority threshold = 0
    li t3, 0xC200000
    li t4, 0
    sw t4, 0(t3)
    // s priority threshold = 7
    li t3, 0xC201000
    li t4, 7
    sw t4, 0(t3)
    // source 3 (GPIO) priority = 1
    li t3, 0xC000000
    li t4, 1
    sw t4, 0x0C(t3)
    // enable source 3 in M Mode
    li t3, 0x0C002000
    li t4, 0b1000
    sw t4, 0(t3)

    li t3, 0x10060000 // load base GPIO memory location
    li t4, 0x1
    sw t4, 0x08(t3)  // enable the first pin as an output
    sw t4, 0x04(t3)  // enable the first pin as an input as well to cause the interrupt to fire

    sw zero, 0x1C(t3) // clear rise_ip
    sw zero, 0x24(t3) // clear fall_ip
    sw zero, 0x2C(t3) // clear high_ip
    sw zero, 0x34(t3) // clear low_ip

    sw t4, 0x28(t3)  // set first pin to interrupt on a rising value
    sw t4, 0x0C(t3)  // write a 1 to the first output pin (cause interrupt)
m_ext_loop:
    addi a3, a3, -1
    bnez a3, m_ext_loop // go through this loop for [a3 value] iterations before returning without performing interrupt
    ret

cause_s_ext_interrupt_GPIO:
    // ========== Configure PLIC ==========
    li a3, 0x40
    // s priority threshold = 0
    li t3, 0xC201000
    li t4, 0
    sw t4, 0(t3)
    // m priority threshold = 7
    li t3, 0xC200000
    li t4, 7
    sw t4, 0(t3)
    // source 3 (GPIO) priority = 1
    li t3, 0xC000000
    li t4, 1
    sw t4, 0x0C(t3)
    // enable source 3 in S mode
    li t3, 0x0C002080
    li t4, 0b1000
    sw t4, 0(t3)

    li t3, 0x10060000 // load base GPIO memory location
    li t4, 0x1
    sw t4, 0x08(t3)  // enable the first pin as an output
    sw t4, 0x04(t3)  // enable the first pin as an input as well to cause the interrupt to fire

    sw zero, 0x1C(t3) // clear rise_ip
    sw zero, 0x24(t3) // clear fall_ip
    sw zero, 0x2C(t3) // clear high_ip
    sw zero, 0x34(t3) // clear low_ip

    sw t4, 0x28(t3)  // set first pin to interrupt on a rising value
    sw t4, 0x0C(t3)  // write a 1 to the first output pin (cause interrupt)
s_ext_loop:
    addi a3, a3, -1
    bnez a3, s_ext_loop // go through this loop for [a3 value] iterations before returning without performing interrupt
    ret

end_trap_triggers:
.endm

.macro TRAP_HANDLER MODE, VECTORED=1, EXT_SIGNATURE=0
    // MODE decides which mode this trap handler will be taken in (M or S mode)
    // Vectored decides whether interrupts are handled with the vector table at trap_handler_MODE (1)
    //      vs Using the non-vector approach the rest of the trap handler takes (0)
    // EXT_SIGNATURE decides whether we will print mtval a string with status.mpie, status.mie, and status.mpp to the signature (1)
    //      vs not saving that info to the signature (0)


    //   Set up the exception Handler, keeping the original handler in tp.
    la ra, trap_handler_\MODE\()
    ori ra, ra, \VECTORED // set mode field of tvec to VECTORED, which will force vectored interrupts if it's 1.

.if (\MODE\() == m)
    csrrw tp, \MODE\()tvec, ra  // tp reserved for "default" trap handler address that needs to be restored before halting this test.
.else
    csrw \MODE\()tvec, ra // we only need save the machine trap handler and this if statement ensures it isn't overwritten
.endif

    li a0, 0
    li a1, 0
    li a2, 0 // reset trap handler inputs to zero

    la t4, 0x02004000    // MTIMECMP register in CLINT
    li t5, 0xFFFFFFFF
    sd t5, 0(t4) // set mtimecmp to 0xFFFFFFFF to really make sure time interrupts don't go off immediately after being enabled

    j trap_handler_end_\MODE\() // skip the trap handler when it is being defined.

    // ---------------------------------------------------------------------------------------------
    // General traps Handler
    //
    //   Handles traps by branching to different behaviors based on mcause.
    //
    //   Note that allowing the exception handler to change mode for a program is a huge security
    //   hole, but this is an expedient way of writing tests that need different modes
    //
    // input parameters:
    //
    //   a0 (x10):
    //       0: halt program with no failures
    //       1: halt program with failure in x11 = a1
    //       2: go to machine mode
    //       3: go to supervisor mode
    //       4: go to user mode
    //       others: do nothing
    //
    //   a1 (x11):
    //       VPN for return address after changing privilege mode.
    //       This should be the base VPN with no offset.
    //       0x0 : defaults to next instruction on the same page the trap was called on.
    //
    //   a2 (x12):
    //       Pagetype of the current address VPN before changing privilege mode
    //       Used so that we can know how many bits of the address are the offset.
    //       Ignored if a1 == 0x0
    //       0: Kilopage
    //       1: Megapage
    //       2: Gigapage
    //       3: Terapage
    //
    // --------------------------------------------------------------------------------------------

.align 6
trap_handler_\MODE\():
    j trap_unvectored_\MODE\() // for the unvectored implementation: jump past this table of addresses into the actual handler
    // *** ASSUMES that a cause value of 0 for an interrupt is unimplemented
    // otherwise, a vectored interrupt handler should jump to trap_handler_\MODE\() + 4 * Interrupt cause code
    // No matter the value of VECTORED, exceptions (not interrupts) are handled in an unvecotred way
    j s_soft_vector_\MODE\()
    j segfault_\MODE\()
    j m_soft_vector_\MODE\()
    j segfault_\MODE\()
    j s_time_vector_\MODE\()
    j segfault_\MODE\()
    j m_time_vector_\MODE\()
    j segfault_\MODE\()
    j s_ext_vector_\MODE\()
    j segfault_\MODE\()
    j m_ext_vector_\MODE\()
    // 12 through >=16 are reserved or designated for platform use

trap_unvectored_\MODE\():
    csrrw sp, \MODE\()scratch, sp // swap sp and scratch so we can use the scratch stack in the trap handler without messing up sp's value or the stack itself.
    // *** NOTE: this means that nested traps will be screwed up but they shouldn't happen in any of these tests

trap_stack_saved_\MODE\(): // jump here after handling vectored interrupt since we already switch sp and scratch there
    // save registers on stack before using
    sd ra, -8(sp)
    sd t0, -16(sp)
    sd t2, -24(sp)

    // Record trap
    csrr ra, \MODE\()cause     // record the mcause
    sd ra, 0(a6)
    addi t1, t1, 8
    addi a6, a6, 8    // update pointers for logging results

.if (\EXT_SIGNATURE\() == 1) // record extra information (MTVAL, some status bits) about traps
    csrr ra, \MODE\()tval
    sd ra, 0(a6)
    addi t1, t1, 8
    addi a6, a6, 8

    csrr ra, \MODE\()status
    .if (\MODE\() == m) // Taking traps in different modes means we want to get different bits from the status register.
        li t0, 0x1888 // mask bits to select MPP, MPIE, and MIE.
    .else
        li t0, 0x122 // mask bits to select SPP, SPIE, and SIE.
    .endif
    and t0, t0, ra
    sd t0, 0(a6) // store masked out status bits to the output
    addi t1, t1, 8
    addi a6, a6, 8

.endif

    // Respond to trap based on cause
    // All interrupts should return after being logged
    csrr ra, \MODE\()cause
    li t0, 0x8000000000000000   // if msb is set, it is an interrupt
    and t0, t0, ra
    bnez t0, interrupt_handler_\MODE\()
    // Other trap handling is specified in the vector Table
    la t0, exception_vector_table_\MODE\()
    slli ra, ra, 3          // multiply cause by 8 to get offset in vector Table
    add t0, t0, ra      // compute address of vector in Table
    ld t0, 0(t0)        // fectch address of handler from vector Table
    jr t0               // and jump to the handler

interrupt_handler_\MODE\():
    la t0, interrupt_vector_table_\MODE\() // NOTE THIS IS NOT THE SAME AS VECTORED INTERRUPTS!!!
    slli ra, ra, 3          // multiply cause by 8 to get offset in vector Table
    add t0, t0, ra      // compute address of vector in Table
    ld t0, 0(t0)        // fectch address of handler from vector Table
    jr t0               // and jump to the handler

segfault_\MODE\():
    ld t2, -24(sp)  // restore registers from stack before faulting
    ld t0, -16(sp)
    ld ra, -8(sp)
    j terminate_test          // halt program.

trapreturn_\MODE\():
    csrr ra, \MODE\()epc
    addi ra, ra, 4 // return to the address AFTER the trapping instruction

trapreturn_specified_\MODE\():
    // reset the necessary pointers and registers (ra, t0, t1, and the return address going to mepc)
    // note that we don't need to change t2 since it was a temporary register with no important address in it.
    // so that when we return to a new virtual address, they're all in the right spot as well.

    beqz a1, trapreturn_finished_\MODE\() // either update values, of go to default return address.

    la t0, trap_return_pagetype_table_\MODE\()
    slli a2, a2, 3
    add t0, t0, a2
    ld a2, 0(t0) // a2 = number of offset bits in current page type

    li t0, 1
    sll t0, t0, a2
    addi t0, t0, -1 // t0 = mask bits for offset into current pagetype

    // reset the top of the stack, which will be put into ra
    ld t2, -8(sp)
    and t2, t0, t2 // t2 = offset for ra
    add t2, t2, a1 // t2 = new address for ra
    sd t2, -8(sp)

    // reset the second spot in the stack, which will be put into t0
    ld t2, -16(sp)
    and t2, t0, t2 // t2 = offset for t0
    add t2, t2, a1 // t2 = new address for t0
    sd t2, -16(sp)

    // reset t1, the pointer for the virtual address of the output of the tests
    and t2, t0, t1 // t2 = offset for t1
    add t1, t2, a1 // t1 = new address for the result pointer

    // reset ra, which temporarily holds the return address that will be written to mepc.
    and ra, t0, ra // ra = offset for the return address
    add ra, ra, a1 // ra = new return address.

    li a1, 0
    li a2, 0 // reset trapreturn inputs to the trap handler

trapreturn_finished_\MODE\():
    csrw \MODE\()epc, ra            // update the epc with address of next instruction
    ld t2, -24(sp)     // restore registers from stack before returning
    ld t0, -16(sp)
    ld ra, -8(sp)
    csrrw sp, \MODE\()scratch, sp // switch sp and scratch stack back to restore the non-trap stack pointer
    \MODE\()ret  // return from trap

// specific exception handlers

ecallhandler_\MODE\():
    // Check input parameter a0. encoding above.
    li t0, 2            // case 2: change to machine mode
    beq a0, t0, ecallhandler_changetomachinemode_\MODE\()
    li t0, 3            // case 3: change to supervisor mode
    beq a0, t0, ecallhandler_changetosupervisormode_\MODE\()
    li t0, 4            // case 4: change to user mode
    beq a0, t0, ecallhandler_changetousermode_\MODE\()
    // unsupported ecalls should segfault
    j segfault_\MODE\()

ecallhandler_changetomachinemode_\MODE\():
    // Force status.MPP (bits 12:11) to 11 to enter machine mode after mret
    // note that it is impossible to return to M mode after a trap delegated to S mode
    li ra, 0b1100000000000
    csrs \MODE\()status, ra
    j trapreturn_\MODE\()

ecallhandler_changetosupervisormode_\MODE\():
    // Force status.MPP (bits 12:11) and status.SPP (bit 8) to 01 to enter supervisor mode after (m/s)ret
    li ra, 0b1000000000000
    csrc \MODE\()status, ra
    li ra, 0b0100100000000
    csrs \MODE\()status, ra
    j trapreturn_\MODE\()

ecallhandler_changetousermode_\MODE\():
    // Force status.MPP (bits 12:11) and status.SPP (bit 8) to 00 to enter user mode after (m/s)ret
    li ra, 0b1100100000000
    csrc \MODE\()status, ra
    j trapreturn_\MODE\()

instrpagefault_\MODE\():
    ld ra, -8(sp) // load return address from stack into ra (the address AFTER the jal to the faulting address)
    j trapreturn_finished_\MODE\() // puts ra into mepc, restores stack and returns to program (outside of faulting page)

instrfault_\MODE\():
    ld ra, -8(sp) // load return address from stack into ra (the address AFTER the jal to the faulting address)
    j trapreturn_finished_\MODE\() // return to the code at ra value from before trap

illegalinstr_\MODE\():
    j trapreturn_\MODE\() // return to the code after recording the mcause

accessfault_\MODE\():
    j trapreturn_\MODE\()

addr_misaligned_\MODE\():
    j trapreturn_\MODE\()

breakpt_\MODE\():
    j trapreturn_\MODE\()

// Vectored interrupt handlers: record the fact that the handler went to the correct vector and then continue to handling
// note: does not mess up any registers, saves and restores them to the stack instead.

s_soft_vector_\MODE\():
    csrrw sp, \MODE\()scratch, sp // swap sp and scratch so we can use the scratch stack in the trap handler without messing up sp's value or the stack itself.
    sd t0, -8(sp) // put t0 on the scratch stack before messing with it
    li t0, 0x7EC01 // write 0x7ec01 (for "VEC"tored and 01 for the interrupt code)
    j vectored_int_end_\MODE\()

m_soft_vector_\MODE\():
    csrrw sp, \MODE\()scratch, sp // swap sp and scratch so we can use the scratch stack in the trap handler without messing up sp's value or the stack itself.
    sd t0, -8(sp) // put t0 on the scratch stack before messing with it
    li t0, 0x7EC03 // write 0x7ec03 (for "VEC"tored and 03 for the interrupt code)
    j vectored_int_end_\MODE\()

s_time_vector_\MODE\():
    csrrw sp, \MODE\()scratch, sp // swap sp and scratch so we can use the scratch stack in the trap handler without messing up sp's value or the stack itself.
    sd t0, -8(sp) // put t0 on the scratch stack before messing with it
    li t0, 0x7EC05 // write 0x7ec05 (for "VEC"tored and 05 for the interrupt code)
    j vectored_int_end_\MODE\()

m_time_vector_\MODE\():
    csrrw sp, \MODE\()scratch, sp // swap sp and scratch so we can use the scratch stack in the trap handler without messing up sp's value or the stack itself.
    sd t0, -8(sp) // put t0 on the scratch stack before messing with it
    li t0, 0x7EC07 // write 0x7ec07 (for "VEC"tored and 07 for the interrupt code)
    j vectored_int_end_\MODE\()

s_ext_vector_\MODE\():
    csrrw sp, \MODE\()scratch, sp // swap sp and scratch so we can use the scratch stack in the trap handler without messing up sp's value or the stack itself.
    sd t0, -8(sp) // put t0 on the scratch stack before messing with it
    li t0, 0x7EC09 // write 0x7ec09 (for "VEC"tored and 08 for the interrupt code)
    j vectored_int_end_\MODE\()

m_ext_vector_\MODE\():
    csrrw sp, \MODE\()scratch, sp // swap sp and scratch so we can use the scratch stack in the trap handler without messing up sp's value or the stack itself.
    sd t0, -8(sp) // put t0 on the scratch stack before messing with it
    li t0, 0x7EC0B // write 0x7ec0B (for "VEC"tored and 0B for the interrupt code)
    j vectored_int_end_\MODE\()

vectored_int_end_\MODE\():
    sd t0, 0(a6) // store to signature to show vectored interrupts succeeded.
    addi t1, t1, 8
    addi a6, a6, 8
    ld t0, -8(sp) // restore t0 before continuing to handle trap in case its needed.
    j trap_stack_saved_\MODE\()

// specific interrupt handlers

soft_interrupt_\MODE\():
    la t0, 0x02000000 // Reset by clearing MSIP interrupt from CLINT
    sw zero, 0(t0)

    csrci \MODE\()ip, 0x2 // clear supervisor software interrupt pending bit
    ld ra, -8(sp) // load return address from stack into ra (the address to return to after causing this interrupt)
    // Note: we do this because the mepc loads in the address of the instruction after the sw that causes the interrupt
    //  This means that this trap handler will return to the next address after that one, which might be unpredictable behavior.
    j trapreturn_finished_\MODE\() // return to the code at ra value from before trap

time_interrupt_\MODE\():
    la t0, 0x02004000    // MTIMECMP register in CLINT
    li t2, 0xFFFFFFFF
    sd t2, 0(t0) // reset interrupt by setting mtimecmp to max
    csrw stimecmp, t2 // reset stime interrupts by doing the same.

    li t0, 0x20
    csrc \MODE\()ip, t0
    ld ra, -8(sp) // load return address from stack into ra (the address to return to after the loop is complete)
    j trapreturn_finished_\MODE\() // return to the code at ra value from before trap

ext_interrupt_\MODE\():
    li t3, 0x10060000 // reset interrupt by clearing all the GPIO bits
    sw zero, 8(t3) // disable the first pin as an output
    sw zero, 40(t3) // write a 0 to the first output pin (reset interrupt)

    // reset PLIC to turn off external interrupts
    // m priority threshold = 7
    li t3, 0xC200000
    li t0, 0x7
    sw t0, 0(t3)
    // s priority threshold = 7
    li t3, 0xC201000
    li t0, 0x7
    sw t0, 0(t3)
    // source 3 (GPIO) priority = 0
    li t3, 0xC000000
    li t0, 0
    sw t0, 0x0C(t3)
    // disable source 3 in M mode
    li t3, 0x0C002000
    li t0, 0b0000
    sw t0, 0(t3)
    // enable source 3 in S mode
    li t3, 0x0C002080
    li t4, 0b0000
    sw t4, 0(t3)

    li t0, 0x200
    csrc \MODE\()ip, t0

    ld ra, -8(sp) // load return address from stack into ra (the address to return to after the loop is complete)
    j trapreturn_finished_\MODE\() // return to the code at ra value from before trap


    // Table of trap behavior
    // lists what to do on each exception (not interrupts)
    // unexpected exceptions should cause segfaults for easy detection
    // Expected exceptions should increment the EPC to the next instruction and return

.data
    .align 3 // aligns this data table to an 8 byte boundary
exception_vector_table_\MODE\():
    .8byte addr_misaligned_\MODE\()      // 0: instruction address misaligned
    .8byte instrfault_\MODE\()    // 1: instruction access fault
    .8byte illegalinstr_\MODE\()  // 2: illegal instruction
    .8byte breakpt_\MODE\()      // 3: breakpoint
    .8byte addr_misaligned_\MODE\()      // 4: load address misaligned
    .8byte accessfault_\MODE\()   // 5: load access fault
    .8byte addr_misaligned_\MODE\()      // 6: store address misaligned
    .8byte accessfault_\MODE\()   // 7: store access fault
    .8byte ecallhandler_\MODE\()  // 8: ecall from U-mode
    .8byte ecallhandler_\MODE\()  // 9: ecall from S-mode
    .8byte segfault_\MODE\()      // 10: reserved
    .8byte ecallhandler_\MODE\()  // 11: ecall from M-mode
    .8byte instrpagefault_\MODE\()    // 12: instruction page fault
    .8byte trapreturn_\MODE\()    // 13: load page fault
    .8byte segfault_\MODE\()      // 14: reserved
    .8byte trapreturn_\MODE\()    // 15: store page fault

    .align 3 // aligns this data table to an 8 byte boundary
interrupt_vector_table_\MODE\():
    .8byte segfault_\MODE\()            // 0: reserved
    .8byte soft_interrupt_\MODE\()    // 1: instruction access fault // the zero spot is taken up by the instruction to skip this table.
    .8byte segfault_\MODE\()            // 2: reserved
    .8byte soft_interrupt_\MODE\()    // 3: breakpoint
    .8byte segfault_\MODE\()            // 4: reserved
    .8byte time_interrupt_\MODE\()    // 5: load access fault
    .8byte segfault_\MODE\()            // 6: reserved
    .8byte time_interrupt_\MODE\()    // 7: store access fault
    .8byte segfault_\MODE\()            // 8: reserved
    .8byte ext_interrupt_\MODE\()     // 9: ecall from S-mode
    .8byte segfault_\MODE\()            // 10: reserved
    .8byte ext_interrupt_\MODE\()     // 11: ecall from M-mode

.align 3
trap_return_pagetype_table_\MODE\():
    .8byte 0xC  // 0: kilopage has 12 offset bits
    .8byte 0x15 // 1: megapage has 21 offset bits
    .8byte 0x1E // 2: gigapage has 30 offset bits
    .8byte 0x27 // 3: terapage has 39 offset bits

.section .text.init

trap_handler_end_\MODE\(): // place to jump to so we can skip the trap handler and continue with the test
.endm

// Test Summary table!

// Test Name            : Description                               : Fault output value                        : Normal output values
// ---------------------:-------------------------------------------:-------------------------------------------:------------------------------------------------------
//   write64_test       : Write 64 bits to address                  : 0x6, 0x7, or 0xf                          : None
//   write32_test       : Write 32 bits to address                  : 0x6, 0x7, or 0xf                          : None
//   write16_test       : Write 16 bits to address                  : 0x6, 0x7, or 0xf                          : None
//   write08_test       : Write 8 bits to address                   : 0x6, 0x7, or 0xf                          : None
//   read64_test        : Read 64 bits from address                 : 0x4, 0x5, or 0xd, then 0xbad              : readvalue in hex
//   read32_test        : Read 32 bits from address                  : 0x4, 0x5, or 0xd, then 0xbad              : readvalue in hex
//   read16_test        : Read 16 bits from address                  : 0x4, 0x5, or 0xd, then 0xbad              : readvalue in hex
//   read08_test        : Read 8 bits from address                   : 0x4, 0x5, or 0xd, then 0xbad              : readvalue in hex
//   executable_test    : test executable on virtual page           : 0x0, 0x1, or 0xc, then 0xbad              : value of t2 modified by execution code (usually 0x111)
//   terminate_test     : terminate tests                           : mcause value for fault                    : from M 0xb, from S 0x9, from U 0x8
//   goto_baremetal     : satp.MODE = bare metal                    : None                                      : None
//   goto_sv39          : satp.MODE = sv39                          : None                                      : None
//   goto_sv48          : satp.MODE = sv48                          : None                                      : None
//   goto_m_mode        : go to machine mode                        : mcause value for fault                    : from M 0xb, from S 0x9, from U 0x8
//   goto_s_mode        : go to supervisor mode                     : mcause value for fault                    : from M 0xb, from S 0x9, from U 0x8
//   goto_u_mode        : go to user mode                           : mcause value for fault                    : from M 0xb, from S 0x9, from U 0x8
//   write_read_csr     : write to specified CSR                    : old CSR value, 0x2, depending on perms    : value written to CSR
//   csr_r_access       : test read-only permissions on CSR         : 0xbad                                     : 0x2, then 0x11

.macro WRITE64 ADDR VAL
    // attempt to write VAL to ADDR
    // Success outputs:
    //      None
    // Fault outputs:
    //      0x6: misaligned address
    //      0x7: access fault
    //      0xf: page fault
    li t4, \VAL
    li t5, \ADDR
    sd t4, 0(t5)
.endm

.macro WRITE32 ADDR VAL
    // all write tests have the same description/outputs as write64
    li t4, \VAL
    li t5, \ADDR
    sw t4, 0(t5)
.endm

.macro WRITE16 ADDR VAL
    // all write tests have the same description/outputs as write64
    li t4, \VAL
    li t5, \ADDR
    sh t4, 0(t5)
.endm

.macro WRITE08 ADDR VAL
    // all write tests have the same description/outputs as write64
    li t4, \VAL
    li t5, \ADDR
    sb t4, 0(t5)
.endm

.macro READ64 ADDR
    // Attempt read at ADDR. Write the value read out to the output *** Consider adding specific test for reading a non known value
    // Success outputs:
    //      value read out from ADDR
    // Fault outputs:
    //      One of the following followed by 0xBAD
    //      0x4: misaligned address
    //      0x5: access fault
    //      0xD: page fault
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    li t4, \ADDR
    ld t2, 0(t4)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
.endm

.macro READ32 ADDR
    // All reads have the same description/outputs as read64.
    // They will store the sign extended value of what was read out at ADDR
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    li t4, \ADDR
    lw t2, 0(t4)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
.endm

.macro READ16 ADDR
    // All reads have the same description/outputs as read64.
    // They will store the sign extended value of what was read out at ADDR
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    li t4, \ADDR
    lh t2, 0(t4)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
.endm

.macro READ08 ADDR
    // All reads have the same description/outputs as read64.
    // They will store the sign extended value of what was read out at ADDR
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    li t4, \ADDR
    lb t2, 0(t4)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
.endm

// These goto_x_mode tests all involve invoking the trap handler,
// So their outputs are inevitably:
//      0x8: test called from U mode
//      0x9: test called from S mode
//      0xB: test called from M mode
// they generally do not fault or cause issues as long as these modes are enabled

.macro GOTO_M_MODE RETURN_VPN=0x0 RETURN_PAGETYPE=0x0
    li a0, 2 // determine trap handler behavior (go to machine mode)
    li a1, \RETURN_VPN // return VPN
    li a2, \RETURN_PAGETYPE // return page types
    ecall // writes mcause to the output.
    // now in S mode
.endm

.macro GOTO_S_MODE RETURN_VPN=0x0 RETURN_PAGETYPE=0x0
    li a0, 3 // determine trap handler behavior (go to supervisor mode)
    li a1, \RETURN_VPN // return VPN
    li a2, \RETURN_PAGETYPE // return page types
    ecall // writes mcause to the output.
    // now in S mode
.endm

.macro GOTO_U_MODE RETURN_VPN=0x0 RETURN_PAGETYPE=0x0
    li a0, 4 // determine trap handler behavior (go to user mode)
    li a1, \RETURN_VPN // return VPN
    li a2, \RETURN_PAGETYPE // return page types
    ecall // writes mcause to the output.
    // now in S mode
.endm

// These tests change virtual memory settings, turning it on/off and changing between types.
// They don't have outputs as any error with turning on virtual memory should reveal itself in the tests

.macro GOTO_BAREMETAL
    // Turn translation off
    li t2, 0 // satp.MODE value for bare metal (0)
    slli t2, t2, 60
    csrw satp, t2
.endm

.macro GOTO_SV39 ASID BASE_PPN
    // Turn on sv39 virtual memory
    li t2, 8 // satp.MODE value for Sv39 (8)
    slli t2, t2, 60
    li t4, \ASID
    slli t4, t4, 44
    or t2, t2, t4 // put ASID into the correct field of SATP
    li t3, \BASE_PPN // Base Pagetable physical page number, satp.PPN field.
    add t2, t2, t3
    csrw satp, t2
.endm

.macro GOTO_SV48 ASID BASE_PPN
    // Turn on sv48 virtual memory
    li t2, 9 // satp.MODE value for Sv39 (8)
    slli t2, t2, 60
    li t4, \ASID
    slli t4, t4, 44
    or t2, t2, t4 // put ASID into the correct field of SATP
    li t3, \BASE_PPN // Base Pagetable physical page number, satp.PPN field.
    add t2, t2, t3
    csrw satp, t2
.endm

.macro WRITE_READ_CSR CSR VAL
    // attempt to write CSR with VAL. Note: this also tests read access to CSR
    // Success outputs:
    //      value read back out from CSR after writing
    // Fault outputs:
    //      The previous CSR value before write attempt
    //      Most likely 0x2, the mcause for illegal instruction if we don't have write or read access
    li t5, 0xbad // load bad value to be overwritten by csrr
    li t4, \VAL\()
    csrw \CSR\(), t4
    csrr t5, \CSR
    sd t5, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
.endm

.macro CSR_R_ACCESS CSR
    // verify that a csr is accessible to read but not to write
    // Success outputs:
    //      0x2, then
    //      0x11
    // Fault outputs:
    //      0xBAD
    csrr t4, \CSR
    csrwi \CSR\(), 0xA // Attempt to write a 'random' value to the CSR
    csrr t5, \CSR
    bne t5, t4, 1f // 1f represents write_access
    li t5, 0x11 // Write failed, confirming read only permissions.
    j 2f // j r_access_end
1: // w_access (write succeeded, violating read-only)
    li t5, 0xBAD
2: // r_access end
    sd t5, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
.endm

.macro EXECUTE_AT_ADDRESS ADDR
    // Execute the code already written to ADDR, returning the value in t2.
    // Note: this test itself doesn't write the code to ADDR because it might be called at a point where we dont have write access to ADDR
    // Assumes the code modifies t2, usually to become 0x111.
    // Sample code:  0x11100393 (li t2, 0x111), 0x00008067 (ret)
    // Success outputs:
    //      modified value of t2. (0x111 if you use the sample code)
    // Fault outputs:
    //      One of the following followed by 0xBAD
    //      0x0: misaligned address
    //      0x1: access fault
    //      0xC: page fault
    fence.i // forces caches and main memory to sync so execution code written to ADDR can run.
    li t2, 0xBAD
    li t3, \ADDR
    jalr t3 // jump to executable test code
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
.endm

// Place this macro in peripheral tests to setup all the PLIC registers to generate external interrupts
.macro SETUP_PLIC
    # Setup PLIC with a series of register writes

    .equ PLIC_INTPRI_GPIO, 0x0C00000C       # GPIO is interrupt 3
    .equ PLIC_INTPRI_UART, 0x0C000028       # UART is interrupt 10
    .equ PLIC_INTPRI_SPI,  0x0C000018       # SPI in interrupt 6
    .equ PLIC_INTPRI_PWM,  0x0C00001C       # PWM in interrupt 42
    .equ PLIC_INTPENDING0, 0x0C001000       # intPending0 register
    .equ PLIC_INTEN00,     0x0C002000       # interrupt enables for context 0 (machine mode) sources 31:1
    .equ PLIC_INTEN10,     0x0C002080       # interrupt enables for context 1 (supervisor mode) sources 31:1
    .equ PLIC_THRESH0,     0x0C200000       # Priority threshold for context 0 (machine mode)
    .equ PLIC_CLAIM0,      0x0C200004       # Claim/Complete register for context 0
    .equ PLIC_THRESH1,     0x0C201000       # Priority threshold for context 1 (supervisor mode)
    .equ PLIC_CLAIM1,      0x0C201004       # Claim/Complete register for context 1

    .8byte PLIC_THRESH0, 0, write32_test    # Set PLIC machine mode interrupt threshold to 0 to accept all interrupts
    .8byte PLIC_THRESH1, 7, write32_test    # Set PLIC supervisor mode interrupt threshold to 7 to accept no interrupts
    .8byte PLIC_INTPRI_GPIO, 7, write32_test # Set GPIO to high priority
    .8byte PLIC_INTPRI_UART, 7, write32_test # Set UART to high priority
    .8byte PLIC_INTPRI_SPI,  7, write32_test # Set SPI to high priority
    .8byte PLIC_INTPRI_PWM, 7, write32_test # Set PWM to high priority
    .8byte PLIC_INTEN00, 0xFFFFFFFF, write32_test # Enable all interrupt sources for machine mode
    .8byte PLIC_INTEN10, 0x00000000, write32_test # Disable all interrupt sources for supervisor mode
.endm

.macro END_TESTS
    // invokes one final ecall to return to machine mode then terminates this program, so the output is
    //      0x8: termination called from U mode
    //      0x9: termination called from S mode
    //      0xB: termination called from M mode
    j terminate_test

.endm

    // ---------------------------------------------------------------------------------------------
    // Test Handler
    //
    // This test handler works in a similar wy to the trap handler. It takes in a few things by reading from a table in memory
    // (see test_cases) and performing certain behavior based on them.
    //
    // Input parameters:
    //
    // t3:
    //     Address input for the test taking place (think: address to read/write, new address to return to, etc...)
    //
    // t4:
    //     Value input for the test taking place (think: value to write, any other extra info needed)
    //
    // t5:
    //     Label for the location of the test that's about to take place
    // ------------------------------------------------------------------------------------------------------------------------------------

.macro INIT_TEST_TABLE

run_test_loop:
    la t0, test_cases

test_loop:
    ld t3, 0(t0) // fetch test case address
    ld t4, 8(t0) // fetch test case value
    ld t5, 16(t0) // fetch test case flag
    addi t0, t0, 24 // set t0 to next test case

    // t0 has the symbol for a test's location in the assembly
    li t2, 0x1FFFFF
    and t5, t5, t2 // This program is always on at least a megapage, so this masks out the megapage offset.
    auipc t2, 0x0
    srli t2, t2, 21
    slli t2, t2, 21 // zero out the bottom 21 bits so the megapage offset of the symbol can be placed there
    or t5, t2, t5 // t5 = virtual address of the symbol for this type of test.

    jr t5

// Test Name             : Description                               : Fault output value     : Normal output values
// ----------------------:-------------------------------------------:------------------------:------------------------------------------------------
//   write64_test        : Write 64 bits to address                  : 0xf                    : None
//   write32_test        : Write 32 bits to address                  : 0xf                    : None
//   write16_test        : Write 16 bits to address                  : 0xf                    : None
//   write08_test        : Write 8 bits to address                   : 0xf                    : None
//   read64_test         : Read 64 bits from address                 : 0xd, 0xbad             : readvalue in hex
//   read32_test         : Read 32 bitsfrom address                  : 0xd, 0xbad             : readvalue in hex
//   read16_test         : Read 16 bitsfrom address                  : 0xd, 0xbad             : readvalue in hex
//   read08_test         : Read 8 bitsfrom address                   : 0xd, 0xbad             : readvalue in hex
//   executable_test     : test executable on virtual page           : 0xc, 0xbad             : value of t2 modified by execution code (usually 0x111)
//   terminate_test      : terminate tests                           : mcause value for fault : from M 0xb, from S 0x9, from U 0x8
//   goto_baremetal      : satp.MODE = bare metal                    : None                   : None
//   goto_sv39           : satp.MODE = sv39                          : None                   : None
//   goto_sv48           : satp.MODE = sv48                          : None                   : None
//   write_mxr_sum       : write sstatus.[19:18] = MXR, SUM bits     : None                   : None
//   goto_m_mode         : go to machine mode                        : mcause value for fault : from M 0xb, from S 0x9, from U 0x8
//   goto_s_mode         : go to supervisor mode                     : mcause value for fault : from M 0xb, from S 0x9, from U 0x8
//   goto_u_mode         : go to user mode                           : mcause value for fault : from M 0xb, from S 0x9, from U 0x8
//   write_pmpcfg_x      : Write one of the pmpcfg csr's             : mstatuses?, 0xD        : readback of pmpcfg value
//   write_pmpaddr_x     : Write one of the pmpaddr csr's            : None                   : readback of pmpaddr value


write64_test:
    // address to write in t3, double value in t4
    sd t4, 0(t3)
    j test_loop // go to next test case

write32_test:
    // address to write in t3, word value in t4
    sw t4, 0(t3)
    j test_loop // go to next test case

write16_test:
    // address to write in t3, halfword value in t4
    sh t4, 0(t3)
    j test_loop // go to next test case

write08_test:
    // address to write in t3, value in t4
    sb t4, 0(t3)
    j test_loop // go to next test case

read64_test:
    // address to read in t3, expected 64 bit value in t4 (unused, but there for your perusal).
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    ld t2, 0(t3)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop // go to next test case

read32_test:
    // address to read in t3, expected 32 bit value in t4 (unused, but there for your perusal).
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    lw t2, 0(t3)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop // go to next test case

read16_test:
    // address to read in t3, expected 16 bit value in t4 (unused, but there for your perusal).
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    lh t2, 0(t3)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop // go to next test case

read08_test:
    // address to read in t3, expected 8 bit value in t4 (unused, but there for your perusal).
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    lb t2, 0(t3)
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop // go to next test case


read04_test:
    // address to read in t3, expected 8 bit value in t4 (unused, but there for your perusal).
    li t2, 0xBAD // bad value that will be overwritten on good reads.
    lb t2, 0(t3)
    andi t2, t2, 0xF // mask lower 4 bits
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop // go to next test case

readmip_test:  // read the MIP into the signature
    csrr t2, mip
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop // go to next test case

readsip_test:  // read the MIP into the signature
    csrr t2, sip
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop // go to next test case

claim_m_plic_interrupts: // clears one non-pending PLIC interrupt
    li t2, 0x0C00000C // GPIO priority
    li t3, 7
    lw t4, 0(t2)
    sw t3, 0(t2)
    sw t4, -4(sp)
    addi sp, sp, -4
    li t2, 0x0C000028 // UART priority
    li t3, 7
    lw t4, 0(t2)
    sw t3, 0(t2)
    sw t4, -4(sp)
    addi sp, sp, -4
    li t2, 0x0C000018 // SPI priority
    li t3, 7
    lw t4, 0(t2)
    sw t3, 0(t2)
    sw t4, -4(sp)
    addi sp, sp, -4
    li t2, 0x0C00001C // PWM priority
    li t3, 7
    lw t4, 0(t2)
    sw t3, 0(t2)
    sw t4, -4(sp)
    addi sp, sp, -4
    li t2, 0x0C002000
    li t3, 0x0C200004
    li t4, 0xFFF
    lw t6, 0(t2) // save current enable status
    sw t4, 0(t2) // enable all relevant interrupts on PLIC
    lw t5, 0(t3) // make PLIC claim
    sw t5, 0(t3) // complete claim made
    sw t6, 0(t2) // restore saved enable status
    li t2, 0x0C00000C // GPIO priority
    li t3, 0x0C000028 // UART priority
    li t6, 0x0C000018 // SPI priority
    li a5, 0x0C00001C // PWM priority
    lw a4, 12(sp) // load stored GPIO prioroty
    sw a4, 0(t2)
    lw a4, 8(sp) // load stored UART priority
    sw a4, 0(t3)
    lw a4, 4(sp) // load stored SPI priority
    sw a4, 0(t6)
    lw a4, 0(sp) // load stored PWM priority
    sw a4, 0(a5)
    addi sp, sp, 16 // restore stack pointer
    j test_loop

claim_s_plic_interrupts: // clears one non-pending PLIC interrupt
    li t2, 0x0C00000C // GPIO priority
    li t3, 7
    lw t4, 0(t2)
    sw t3, 0(t2)
    sw t4, -4(sp)
    addi sp, sp, -4
    li t2, 0x0C000028 // UART priority
    li t3, 7
    lw t4, 0(t2)
    sw t3, 0(t2)
    sw t4, -4(sp)
    addi sp, sp, -4
    li t2, 0x0C002080
    li t3, 0x0C201004
    li t4, 0xFFF
    lw t6, 0(t2) // save current enable status
    sw t4, 0(t2) // enable all relevant interrupts on PLIC
    lw t5, 0(t3) // make PLIC claim
    sw t5, 0(t3) // complete claim made
    sw t6, 0(t2) // restore saved enable status
    li t2, 0x0C00000C // GPIO priority
    li t3, 0x0C000028 // UART priority
    lw t4, 4(sp) // load stored GPIO and UART priority
    lw t5, 0(sp)
    addi sp, sp, 8 // restore stack pointer
    sw t4, 0(t2)
    sw t5, 0(t3)
    j test_loop

uart_lsr_intr_wait: // waits for interrupts to be ready
    li t2, 0x10000002 // IIR
    li t4, 0x6
uart_lsr_intr_loop:
    lb t3, 0(t2)
    andi t3, t3, 0x7
    bne t3, t4, uart_lsr_intr_loop
uart_save_iir_status:
    sd t3, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop

uart_data_wait:
    li t2, 0x10000002
    lbu t3, 0(t2) // save IIR before reading LSR might clear it
    // Check IIR to see if theres an rxfifio or txempty interrupt and handle it before continuing.
    li t2, 0xCC // Value in IIR for Fifo Enabled, with timeout interrupt pending
    beq t3, t2, uart_rxfifo_timout
    li t2, 0xC2 // Value in IIR for Fifo Enabled, with txempty interrupt pending.
    beq t3, t2, uart_txempty_intr
    li t2, 0x10000005 // There needs to be an instruction here between the beq and the lb or the tests will hang
    lb t4, 0(t2) // read LSR
    li t2, 0x61
    bne t4, t2, uart_data_wait // wait until all transmissions are done and data is ready
    j uart_data_ready
uart_rxfifo_timout:
    li t2, 0x10000000 // read from the fifo to clear the rx timeout error
    lb t5, 0(t2)
    sb t5, 0(t2) // write back to the fifo to make sure we have the same data so expected future overrun errors still occur.
    j uart_data_wait
uart_txempty_intr:
    li t2, 0x10000002
    lb t5, 0(t2) // Read IIR to clear this bit in LSR
    j uart_data_wait

uart_data_ready:
    li t2, 0x10000002
    lbu t3, 0(t2) // re read IIR
    andi t4, t4, 0x9F // mask THRE and TEMT from IIR signature
    li t2, 0
    sd t2, 0(t1) // clear entry deadbeef from memory
    sb t3, 1(t1) // IIR
    sb t4, 0(t1) // LSR
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop

uart_clearmodemintr:
    li t2, 0x10000006
    lb t2, 0(t2)
    j test_loop

spi_data_wait:
    li t2, 0x10040054
    sw t4, 0(t2) // set rx watermark level
    li t2, 0x10040074
    lw t3, 0(t2) //read ip (interrupt pending register)
    slli t3, t3, 56
    srli t3, t3, 56
    li t2, 0x00000002
    bge t3, t2, spi_data_ready //branch to done if transmission complete
    j spi_data_wait //else check again

spi_data_ready:
    li t2, 0x10040070
    li t3, 0x00000000
    sw t3, 0(t2) //disable rx watermark interrupt
    j test_loop

spi_burst_send: //function for loading multiple frames at once to test delays without returning to test loop
    mv t2, t4
    sw t2, 0(t3)
    srli t2, t2, 8
    sw t2, 0(t3)
    srli t2, t2, 8
    sw t2, 0(t3)
    srli t2, t2, 8
    sw t2, 0(t3)
    j test_loop

pwm_cycle_wait: //counts number of pwm cycles
    rdcycle a4 //read starting cycle into a4
    li t2, 0x10020000 // pwm start address
    lw t3, 32(t2) //load comp0 into t3
    lw t6, 0(t2)   //load scale factor into t6
    andi t6, t6, 0x0000000F
    add t6, t6, t4 // create total shift for end wait time by adding shift factor and log2(numcycles)
    sll t3, t3, t6 //shift compare by (scale factor + )
    add t2, t3, a4 //find estimated end time
    li t4, 0x1006002C // load gpio rise_ip address
    li t5, 0x0
    li t6, 0xFFFFFFFF
    lw t3, 0(t4)

pwm_cycle_branch:
    rdcycle t3 //read current cycle num
    bgt t3, t2, pwm_over //if cycle over estimated end time, end
    lw t3, 0(t4) //load GPIO 0-3 high_ip
    bgtz t3, pwm_cycle_increment
    j pwm_cycle_branch

pwm_cycle_increment:
    addi t5, t5, 0x1
    j pwm_wait_half

pwm_wait_half:
    sw t6, 0(t4) // clear high_ip
    lw t3, 0(t4) //load high_ip
    bgtz t3, pwm_wait_half //wait for pwm cycle to end
    j pwm_cycle_branch

pwm_over: //resets pwm enables and clears interrupt registers
    li t2, 0x10020000
    li t3, 0x00000000
    sw t3, 0(t2) //clear pwm config
    sw t3, 8(t2) //set pwm count to 0
    sw t6, 0(t4) // clear high_ip
    sd t5, 0(t1) //store num of cycles
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop

pwm_dumb_over: //resets pwm enables and clears interrupt registers
    li t2, 0x10020000
    li t3, 0x00000000
    sw t3, 0(t2) //clear pwm config
    sw t3, 8(t2) //set pwm count to 0
    j test_loop

pwm_cycle_wait_center: //function for waiting t4 pwm cycles for inspection tests when in center mode
    rdcycle a4 //read starting cycle into t4
    li t2, 0x10020000 // pwm start address
    li t3, 0xFFFF //load max count (centered)
    lw t6, 0(t2)   //load scale factor into t6
    andi t6, t6, 0x0000000F
    add t6, t6, t4 // create total shift for end wait time by adding shift factor and log2(numcycles)
    sll t3, t3, t6 //shift compare by (scale factor + )
    add t2, t3, a4 //find estimated end time
    li t4, 0x1006002C // load gpio rise_ip address
    li t5, 0x0
    li t6, 0xFFFFFFFF
    lw t3, 0(t4)
    j pwm_cycle_branch

pwm_dumb_wait: // waits an estimated 8 pwm cycles from timer and scale
    rdcycle t5 //read starting cycle into t4
    li t2, 0x10020000 // comp0 register
    lw t3, 32(t2) //load comp0 into t3
    lw t6, 0(t2)   //load scale factor into t6
    andi t6, t6, 0x0000000F
    add t6, t6, t4 // create total shift for end wait time by adding shift factor and log2(numcycles)
    sll t3, t3, t6 //shift compare by (scale factor + )
    add t5, t3, t5 //find estimated end time

pwm_dumb_cycle:
    rdcycle t4
    bgt t4, t5, pwm_dumb_over
    j pwm_dumb_cycle

pwm_dumb_wait_center:
    rdcycle t5
    li t2, 0x10020000 // comp0 register
    li t3, 0xFFFF //center technique requires max compare time
    lw t6, 0(t2)   //load scale factor into t6
    andi t6, t6, 0x0000000F
    add t6, t6, t4 // create total shift for end wait time by adding shift factor and log2(numcycles)
    sll t3, t3, t6 //shift compare by (scale factor + )
    add t5, t3, t5 //find estimated end time
    j pwm_dumb_cycle

goto_s_mode:
    // return to address in t3,
    li a0, 3 // Trap handler behavior (go to supervisor mode)
    mv a1, t3 // return VPN
    mv a2, t4 // return page types
    ecall // writes mcause to the output.
    // now in S mode
    j test_loop

goto_m_mode:
    li a0, 2 // Trap handler behavior (go to machine mode)
    mv a1, t3 // return VPN
    mv a2, t4 // return page types
    ecall // writes mcause to the output.
    j test_loop

goto_u_mode:
    li a0, 4 // Trap handler behavior (go to user mode)
    mv a1, t3 // return VPN
    mv a2, t4 // return page types
    ecall // writes mcause to the output.
    j test_loop

goto_baremetal:
    // Turn translation off
    GOTO_BAREMETAL
    j test_loop // go to next test case

goto_sv39:
    // Turn sv39 translation on
    // Base PPN in t3, ASID in t4
    li t2, 8 // satp.MODE value for sv39 (8)
    slli t2, t2, 60
    slli t4, t4, 44
    or t2, t2, t4 // put ASID into the correct field of SATP
    or t2, t2, t3 // Base Pagetable physical page number, satp.PPN field.
    csrw satp, t2
    j test_loop // go to next test case

goto_sv48:
    // Turn sv48 translation on
    // Base PPN in t3, ASID in t4
    li t2, 9 // satp.MODE value for sv48 (9)
    slli t2, t2, 60
    slli t4, t4, 44
    or t2, t2, t4 // put ASID into the correct field of SATP
    or t2, t2, t3 // Base Pagetable physical page number, satp.PPN field.
    csrw satp, t2
    j test_loop // go to next test case

write_mxr_sum:
    // writes sstatus.[mxr, sum] with the (assumed to be) 2 bit value in t4. also assumes we're in S or M mode
    li t5, 0xC0000 // mask bits for MXR, SUM
    not t2, t4
    slli t2, t2, 18
    and t2, t2, t5
    slli t4, t4, 18
    csrc sstatus, t2
    csrs sstatus, t4
    j test_loop

read_write_mprv:
    // reads old mstatus.mprv value to output, then
    // Writes mstatus.mprv with the 1 bit value in t4. assumes we're in m mode
    li t5, 0x20000 // mask bits for mprv
    csrr t2, mstatus
    and t2, t2, t5
    srli t2, t2, 17
    sd t2, 0(t1) // store old mprv to output
    addi t1, t1, 8
    addi a6, a6, 8

    not t2, t4
    slli t2, t2, 17
    slli t4, t4, 17
    csrc mstatus, t2
    csrs mstatus, t4 // clear or set mprv bit
    li t2, 0x1800
    csrc mstatus, t2
    li t2, 0x800
    csrs mstatus, t2 // set mpp to supervisor mode to see if mprv=1 really executes in the mpp mode
    j test_loop


write_pmpcfg_0:
    // writes the value in t4 to the pmpcfg register specified in t3.
    // then writes the final value of pmpcfgX to the output.
    csrw pmpcfg0, t4
    csrr t5, pmpcfg0
    j write_pmpcfg_end

write_pmpcfg_2:
    csrw pmpcfg2, t4
    csrr t5, pmpcfg2 // I would use csrrw but we need the value AFTER the csr has been written
    j write_pmpcfg_end

write_pmpcfg_end:
    sd t5, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop

write_pmpaddr_0:
    // write_read_csr pmpaddr0, t4
    // writes the value in t4 to the pmpaddr register specified in t3.
    // then writes the final value of pmpaddrX to the output.
    csrw pmpaddr0, t4
    csrr t5, pmpaddr0
    j write_pmpaddr_end

write_pmpaddr_1:
    csrw pmpaddr1, t4
    csrr t5, pmpaddr1
    j write_pmpaddr_end

write_pmpaddr_2:
    csrw pmpaddr2, t4
    csrr t5, pmpaddr2
    j write_pmpaddr_end

write_pmpaddr_3:
    csrw pmpaddr3, t4
    csrr t5, pmpaddr3
    j write_pmpaddr_end

write_pmpaddr_4:
    csrw pmpaddr4, t4
    csrr t5, pmpaddr4
    j write_pmpaddr_end

write_pmpaddr_5:
    csrw pmpaddr5, t4
    csrr t5, pmpaddr5
    j write_pmpaddr_end

write_pmpaddr_6:
    csrw pmpaddr6, t4
    csrr t5, pmpaddr6
    j write_pmpaddr_end

write_pmpaddr_7:
    csrw pmpaddr7, t4
    csrr t5, pmpaddr7
    j write_pmpaddr_end

write_pmpaddr_8:
    csrw pmpaddr8, t4
    csrr t5, pmpaddr8
    j write_pmpaddr_end

write_pmpaddr_9:
    csrw pmpaddr9, t4
    csrr t5, pmpaddr9
    j write_pmpaddr_end

write_pmpaddr_10:
    csrw pmpaddr10, t4
    csrr t5, pmpaddr10
    j write_pmpaddr_end

write_pmpaddr_11:
    csrw pmpaddr11, t4
    csrr t5, pmpaddr11
    j write_pmpaddr_end

write_pmpaddr_12:
    csrw pmpaddr12, t4
    csrr t5, pmpaddr12
    j write_pmpaddr_end

write_pmpaddr_13:
    csrw pmpaddr13, t4
    csrr t5, pmpaddr13
    j write_pmpaddr_end

write_pmpaddr_14:
    csrw pmpaddr14, t4
    csrr t5, pmpaddr14
    j write_pmpaddr_end

write_pmpaddr_15:
    csrw pmpaddr15, t4
    csrr t5, pmpaddr15
    j write_pmpaddr_end

write_pmpaddr_end:
    sd t5, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop

write_mideleg:
    // writes the value in t4 to the mideleg register
    // Doesn't log anything
    csrw mideleg, t4
    j test_loop

write_menvcfg:
    // writes the value in t4 to the menvcfg register
    // Doesn't log anything
    csrw menvcfg, t4
    j test_loop

executable_test:
    // Execute the code at the address in t3, returning the value in t2.
    // Assumes the code modifies t2, to become the value stored in t4 for this test.
    fence.i // forces cache and main memory to sync so execution code written by the program can run.
    li t2, 0xBAD
    jalr t3
    sd t2, 0(t1)
    addi t1, t1, 8
    addi a6, a6, 8
    j test_loop

.endm

// notably, terminate_test is not a part of the test table macro because it needs to be defined
// in any type of test, macro or test table, for the trap handler to work
terminate_test:

    li a0, 2 // Trap handler behavior (go to machine mode)
    ecall //  writes mcause to the output.
    csrw mtvec, tp  // restore original trap handler to halt program

RVTEST_CODE_END
RVMODEL_HALT

.macro TEST_STACK_AND_DATA

RVTEST_DATA_BEGIN
.align 4
rvtest_data:
.word 0xbabecafe
RVTEST_DATA_END

.align 3 // align stack to 8 byte boundary
stack_bottom:
    .fill 1024, 4, 0xdeadbeef
stack_top:

.align 3
mscratch_bottom:
    .fill 512, 4, 0xdeadbeef
mscratch_top:

.align 3
sscratch_bottom:
    .fill 512, 4, 0xdeadbeef
sscratch_top:



RVMODEL_DATA_BEGIN

test_1_res:
    .fill 1024, 4, 0xdeadbeef

sig_end_canary:
.int 0x0
rvtest_sig_end:
RVMODEL_DATA_END

#ifdef rvtest_mtrap_routine

mtrap_sigptr:
    .fill 64*(XLEN/32),4,0xdeadbeef

#endif

#ifdef rvtest_gpr_save

gpr_save:
    .fill 32*(XLEN/32),4,0xdeadbeef

#endif

.endm
