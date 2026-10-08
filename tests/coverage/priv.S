///////////////////////////////////////////
// priv.S
//
// Written: David_Harris@hmc.edu 23 March 2023
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

main:
    # Tests sret in machine mode
    la t1, sretdone
    csrw sepc, t1
    sret
sretdone:
    addi t2, x0, 42

    # switch to user mode
    li a0, 0
    ecall
    sret #should be treated as illegal instruction
    mret #mret in user mode and should be illegal

    # switch to supervisor mode
    li a0, 1
    ecall

    # Test read to stimecmp fails when MCOUNTEREN_TM is not set
    li t1, -3
    csrw stimecmp, t1
    csrr t0, stimecmp


    # satp write with mstatus.TVM = 1
    bseti t0, zero, 20
    csrs mstatus, t0
    csrw satp, zero

    # STIMECMP from S mode
    # 1st is when MENVCFG_STCE is cleared
    li a0, 3
    ecall # starts in M-mode
    li t1, -3
    csrw stimecmp, t1 # sets stimecmp to large value to prevent it from interrupting immediately
    li t0, 2
    csrs mstatus, t0 # enables sie
    li t0, 32
    csrs sie, t0 # enables sie.stie
    csrw menvcfg, x0
    li a0, 1
    ecall   # enter S-mode
    csrw stimecmp, zero
    li a0, 3
    ecall # in M-mode
    li t0, 32
    csrs mip, t0
    li a0, 1
    ecall # in S-mode and expects stimer interrupt to occur
    li a0, 3
    ecall   # return to M-mode
    csrsi mcounteren, 2 # mcounteren_tm = 1
    li a0, 1
    ecall   # supervisor mode again
    csrw stimecmp, zero
    li a0, 3
    ecall  # machine mode again

    # STIMECMP from S mode
    # 2nd is when MENVCFG_STCE is set
    csrci mcounteren, 2 # mcounteren_tm = 0
    li t0, 1
    slli t0, t0, 63
    csrw menvcfg, t0
    li a0, 1
    ecall   # enter S-mode
    csrw stimecmp, zero
    li a0, 3
    ecall   # return to M-mode
    csrsi mcounteren, 2 # mcounteren_tm = 1
    li a0, 1
    ecall   # supervisor mode again
    csrw stimecmp, zero
    li a0, 3
    ecall  # machine mode again

    # writes to FCSR
    li t0, 1
    slli t0, t0, 13
    csrs mstatus, t0
    li t0, 1
    csrw fcsr, t0

    # switch to supervisor mode
    li a0, 1
    ecall

    # Test write to STVAL, SCAUSE, SEPC, and STIMECMP CSRs
    li t0, 0
    csrw stval, t0
    csrw scause, t0
    csrw sepc, t0
    csrw stimecmp, t0
    csrw scounteren, zero
    csrw satp, zero


    # Switch to machine mode
    li a0, 3
    ecall

    # Write to MCOUNTINHIBIT CSR
    csrw mcountinhibit, t0

    # Testing the HPMCOUNTERM performance counter: writing
    # Base address is 2816 (MHPMCOUNTERBASE)
    # There are 32 HPMCOUNTER registers
    csrw 2816, t0
    csrw 2817, t0
    csrw 2818, t0
    csrw 2819, t0
    csrw 2820, t0
    csrw 2821, t0
    csrw 2822, t0
    csrw 2823, t0
    csrw 2824, t0
    csrw 2825, t0
    csrw 2826, t0
    csrw 2827, t0
    csrw 2828, t0
    csrw 2829, t0
    csrw 2830, t0
    csrw 2831, t0
    csrw 2832, t0
    csrw 2833, t0
    csrw 2834, t0
    csrw 2835, t0
    csrw 2836, t0
    csrw 2837, t0
    csrw 2838, t0
    csrw 2839, t0
    csrw 2840, t0
    csrw 2841, t0
    csrw 2842, t0
    csrw 2843, t0
    csrw 2844, t0
    csrw 2845, t0
    csrw 2846, t0
    csrw 2847, t0

    # Testing the HPMCOUNTERM performance counter: reading
    csrr t0, 2817

    # Test writes to pmp address registers
    csrw 951, t0
    csrw 952, t0
    csrw 953, t0
    csrw 954, t0
    csrw 955, t0
    csrw 956, t0
    csrw 957, t0
    csrw 958, t0


    # Testing writes to MTVAL, MCAUSE
    li t0, 0
    csrw mtval, t0
    csrw mcause, t0

    # set mstatus to enable floating point registers (mstatus.FS = 11)
    bseti t1, zero, 13
    csrs mstatus, t1
    bseti t1, zero, 14
    csrs mstatus, t1

    # Test writes to floating point CSRs
    csrw frm, t0
    csrw fflags, t0

    # CSRC MCOUNTEREN Register
    # Go to machine mode
    li a0, 3
    ecall
    # Activate HPM3
    li t0, -1
    csrw mcounteren, t0
    csrw scounteren, t0

    # Go to supervisor
    li a0, 1
    ecall
    #try to write to HPMs
    csrw 333, t0
    #go to user mode
    li a0, 0
    ecall
    csrr t0, hpmcounter22

    # setting registers bits to 0
    li a0, 3 # back to machine mode
    ecall
    li t0, 0
    csrw mcounteren, t0
    csrw scounteren, t0

    #getting the remainder of PMD instructions

    #go to user mode
    li a0, 0
    ecall
    #set status TVM to 0 by writing to bit 20 of mstatus as 0
    #bseti t0, zero, 20
    sfence.vma zero, zero

    # Go to supervisor mode
    li a0, 1
    ecall

    sfence.vma zero, zero

    li a0, 3
    ecall

    # Write to satp when status.TVM is 1 from machine mode
    bseti t0, zero, 20
    csrs mstatus, t0

    csrw satp, t0



    # Test checking privilege for reading counters (using counter 22 as an example)

    # Go to machine mode
    li a0, 3
    ecall

    # Set SCOUNTEREN to all 0s, MCOUNTEREN to all 1s
    li t0, 0
    csrw scounteren, t0
    li t1, -1
    csrw mcounteren, t1


    # Go to supervisor mode
    li a0, 1
    ecall

    # try to read from HPM22
    csrr t0, hpmcounter22

    # go to user mode
    li a0, 0
    ecall

    csrr t0, hpmcounter22

    #getting the mpp and mstatus Mpriv condition met
    #go to machine mode
    li a0, 3
    ecall
    # set bit 17 of mstatus to enable STATUS_MPRV
    bseti t1, zero, 17
    csrs mstatus, t1

    li a0, 3
    ecall

    # set bit 21 of mstatus to 0 to disable STATUS_TW
    csrr t1, mstatus
    bseti t2, zero, 21
    not t2, t2
    and t1, t1, t2
    csrs mstatus, t1

    # go to user mode
    li a0, 0
    ecall

    wfi



    # Test uncovered privdec instructions
    li a0, 3
    ecall
    # exercise sfence.inval.ir instruction
    sfence.inval.ir

    # exercise sret with rs1 not 0
    .word 0x102F8073

    # illegal ebreak with nonzero rs1
    .word 0x00110073


    # cover mret when mpp = 3 and mprv = 1
    li a0, 3
    ecall               # enter machine mode
    bseti t0, zero, 17
    csrs mstatus, t0    # set MPRV
    li t1, 0x00001800
    csrs mstatus, t1    # set MPP=3
    la t1, finished
    csrr t0, mepc
    csrw mepc, t1       # set mepc for mret to jump to
    mret


finished: j done
