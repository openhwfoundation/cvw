///////////////////////////////////////////
// WALLY-init-lib.h
//
// Written: David_Harris@hmc.edu 21 March 2023
//
// Purpose: Initialize stack, handle interrupts, terminate test case
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
// The PMP tests are sensitive to the exact addresses in this code, so unfortunately
// modifying anything breaks those tests.

.section .text.init
.global rvtest_entry_point

rvtest_entry_point:
    la sp, topofstack       # Initialize stack pointer (not used)

#Set up interrupts
    la t0, trap_handler
    csrw mtvec, t0      # Initialize MTVEC to trap_handler
    csrw mideleg, zero  # Don't delegate interrupts
    csrw medeleg, zero  # Don't delegate exceptions
#li t0, -1 #set mtimecmp to biggest number so it doesnt interrupt again
#li t1, 0x02004000 #MTIMECMP in CLINT
#sd t0, 0(t1)
    li t0, 0x80
#li t0, 0x00
    csrw mie, t0        # Enable machine timer interrupt
    la t0, topoftrapstack
    csrw mscratch, t0   # MSCRATCH holds trap stack pointer
    csrsi mstatus, 0x8  # Turn on mstatus.MIE global interrupt enable
#set up PMP so user and supervisor mode can access full address space
    csrw pmpcfg0, 0xF   # configure PMP0 to TOR RWX
    li t0, 0xFFFFFFFF
    csrw pmpaddr0, t0   # configure PMP0 top of range to 0xFFFFFFFF to allow all 32-bit addresses
    j main              # Call main function in user test program

done:
    li a0, 4            # argument to finish program
    ecall               # system call to finish program
    j self_loop         # wait forever (not taken)

.align 4                # trap handlers must be aligned to multiple of 4
trap_handler:
#Load trap handler stack pointer tp
    csrrw tp, mscratch, tp  # swap MSCRATCH and tp
    sd t0, 0(tp)        # Save t0 and t1 on the stack
    sd t1, -8(tp)
    csrr t0, mcause     # Check the cause
    csrr t1, mtval      # And the trap value
    bgez t0, exception  # if msb is clear, it is an exception

interrupt:              # must be a timer interrupt
    li t0, -1           # set mtimecmp to biggest number so it doesnt interrupt again
    li t1, 0x02004000   # MTIMECMP in CLIN
    sd t0, 0(t1)
    csrw stimecmp, t0   # sets stimecmp to big number so it doesnt interrupt
    li t0, 32
    csrc sip, t0        # clears stimer interrupt
    j trap_return       # clean up and return

exception:
    csrr t0, mcause
    li t1, 0xC          # is it an instruction page fault
    li a0, 3            # set a0 to 3 to ecall looks like a program terminate
    beq t0, t1, ecall   # terminate program for instruction page fault
    li t1, 8            # is it an ecall trap?
    andi t0, t0, 0xFC # if CAUSE = 8, 9, or 11
    bne t0, t1, trap_return # ignore other exceptions

ecall:
    li t0, 4
    beq a0, t0, write_tohost    # call 4: terminate program
    bltu a0, t0, changeprivilege    # calls 0-3: change privilege level
    j trap_return       # ignore other ecalls

changeprivilege:
    li t0, 0x00001800   # mask off mstatus.MPP in bits 11-12
    csrc mstatus, t0
    andi a0, a0, 0x003  # only keep bottom two bits of argument
    slli a0, a0, 11     # move into mstatus.MPP position
    csrs mstatus, a0    # set mstatus.MPP with desired privilege

trap_return:            # return from trap handler
    csrr t0, mepc  # get address of instruction that caused exception
    li t1, 0x20000
    csrs mstatus, t1    # set mprv bit to fetch instruction with permission of code that trapped
    lh t0, 0(t0)   # get instruction that caused exception
    csrc mstatus, t1    # clear mprv bit to restore normal operation
    li t1, 3
    and t0, t0, t1  # mask off upper bits
    beq t0, t1, instr32  # if lower 2 bits are 11, instruction is uncompresssed
    li t0, 2        # increment PC by 2 for compressed instruction
    j updateepc
instr32:
    li t0, 4
updateepc:
    csrr t1, mepc   # add 2 or 4 (from t0) to MEPC to determine return Address
    add t1, t1, t0
    csrw mepc, t1

    ld t1, -8(tp)       # restore t1 and t0
    ld t0, 0(tp)
    csrrw tp, mscratch, tp  # restore tp
    mret                # return from trap

write_tohost:
    la t1, tohost
    li t0, 1            # 1 for success, 3 for failure
    sd t0, 0(t1)        # send success code

self_loop:
    j self_loop         # wait

.section .tohost
tohost:                 # write to HTIF
    .dword 0
fromhost:
    .dword 0

.EQU XLEN,64
begin_signature:
    .fill 6*(XLEN/32),4,0xdeadbeef    #
end_signature:

#Initialize stack with room for 512 bytes
.bss
    .space 512
topofstack:
#And another stack for the trap handler
.bss
    .space 512
topoftrapstack:

.align 4
.section .text.main
