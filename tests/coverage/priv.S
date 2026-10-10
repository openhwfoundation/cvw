///////////////////////////////////////////
// priv.S
//
// Written: David_Harris@hmc.edu 23 March 2023
//
// Purpose: Test coverage for EBU
//
// Checks: a trap log records mcause, mepc and mtval of every trap and must match expected_traps
// exactly: each illegal privileged instruction or CSR access traps with cause 2 at that instruction
// with the instruction bits in mtval, each ecall reports the privilege mode it came from (8 = U,
// 9 = S, 11 = M, which also checks that sret from M-mode returned to U through sstatus.SPP), and
// nothing else traps, including no interrupt (failure indices 0x100-0x1FF).  stimecmp keeps its
// value across the illegal S-mode writes and takes the legal ones (indices 1-4 and 6), and the
// final mret to M-mode with MPRV = 1 leaves MPRV set and MPP = U (index 5).
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
#include "WALLY-selfcheck.h"

// CHECK_CSR csr, expected, index: fail with index unless the CSR reads expected
.macro CHECK_CSR csr, expected, index
    csrr a1, \csr
    li a2, \expected
    SC_CHECK_EQ a1, a2, \index
.endm

main:
    la t0, log_trap
    csrw mtvec, t0

    # Tests sret in machine mode
    la t1, sretdone
    csrw sepc, t1
    sret
sretdone:
    addi t2, x0, 42

    # switch to user mode
    li a0, 0
trap01:
    ecall
trap02:
    sret #should be treated as illegal instruction
trap03:
    mret #mret in user mode and should be illegal

    # switch to supervisor mode
    li a0, 1
trap04:
    ecall

    # Test read to stimecmp fails when MCOUNTEREN_TM is not set
    li t1, -3
trap05:
    csrw stimecmp, t1
trap06:
    csrr t0, stimecmp


    # satp write with mstatus.TVM = 1
    bseti t0, zero, 20
trap07:
    csrs mstatus, t0
    csrw satp, zero

    # STIMECMP from S mode
    # 1st is when MENVCFG_STCE is cleared
    li a0, 3
trap08:
    ecall # starts in M-mode
    li t1, -3
    csrw stimecmp, t1 # sets stimecmp to large value to prevent it from interrupting immediately
    li t0, 2
    csrs mstatus, t0 # enables sie
    li t0, 32
    csrs sie, t0 # enables sie.stie
    csrw menvcfg, x0
    li a0, 1
trap09:
    ecall   # enter S-mode
trap10:
    csrw stimecmp, zero
    li a0, 3
trap11:
    ecall # in M-mode
    CHECK_CSR stimecmp, -3, 1       # the illegal S-mode write left stimecmp unchanged
    li t0, 32
    csrs mip, t0
    li a0, 1
trap12:
    ecall # in S-mode and expects stimer interrupt to occur
    li a0, 3
trap13:
    ecall   # return to M-mode
    csrsi mcounteren, 2 # mcounteren_tm = 1
    li a0, 1
trap14:
    ecall   # supervisor mode again
trap15:
    csrw stimecmp, zero
    li a0, 3
trap16:
    ecall  # machine mode again
    CHECK_CSR stimecmp, -3, 2       # still illegal with mcounteren.TM = 1 while menvcfg.STCE = 0

    # STIMECMP from S mode
    # 2nd is when MENVCFG_STCE is set
    csrci mcounteren, 2 # mcounteren_tm = 0
    li t0, 1
    slli t0, t0, 63
    csrw menvcfg, t0
    li a0, 1
trap17:
    ecall   # enter S-mode
trap18:
    csrw stimecmp, zero
    li a0, 3
trap19:
    ecall   # return to M-mode
    CHECK_CSR stimecmp, -3, 3       # still illegal with menvcfg.STCE = 1 while mcounteren.TM = 0
    csrsi mcounteren, 2 # mcounteren_tm = 1
    li a0, 1
trap20:
    ecall   # supervisor mode again
    csrw stimecmp, zero
    li a0, 3
trap21:
    ecall  # machine mode again
    CHECK_CSR stimecmp, 0, 4        # legal with both set

    # writes to FCSR
    li t0, 1
    slli t0, t0, 13
    csrs mstatus, t0
    li t0, 1
    csrw fcsr, t0

    # switch to supervisor mode
    li a0, 1
trap22:
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
trap23:
    ecall

    # Write to MCOUNTINHIBIT CSR
    csrw mcountinhibit, t0

    # Testing the HPMCOUNTERM performance counter: writing
    # Base address is 2816 (MHPMCOUNTERBASE)
    # There are 32 HPMCOUNTER registers
    csrw 2816, t0
trap24:
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
trap25:
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
trap26:
    ecall
    # Activate HPM3
    li t0, -1
    csrw mcounteren, t0
    csrw scounteren, t0

    # Go to supervisor
    li a0, 1
trap27:
    ecall
    #try to write to HPMs
    csrw 333, t0
    #go to user mode
    li a0, 0
trap28:
    ecall
    csrr t0, hpmcounter22

    # setting registers bits to 0
    li a0, 3 # back to machine mode
trap29:
    ecall
    li t0, 0
    csrw mcounteren, t0
    csrw scounteren, t0

    #getting the remainder of PMD instructions

    #go to user mode
    li a0, 0
trap30:
    ecall
    #set status TVM to 0 by writing to bit 20 of mstatus as 0
    #bseti t0, zero, 20
trap31:
    sfence.vma zero, zero

    # Go to supervisor mode
    li a0, 1
trap32:
    ecall

    sfence.vma zero, zero

    li a0, 3
trap33:
    ecall

    # Write to satp when status.TVM is 1 from machine mode
    bseti t0, zero, 20
    csrs mstatus, t0

    csrw satp, t0



    # Test checking privilege for reading counters (using counter 22 as an example)

    # Go to machine mode
    li a0, 3
trap34:
    ecall

    # Set SCOUNTEREN to all 0s, MCOUNTEREN to all 1s
    li t0, 0
    csrw scounteren, t0
    li t1, -1
    csrw mcounteren, t1


    # Go to supervisor mode
    li a0, 1
trap35:
    ecall

    # try to read from HPM22
    csrr t0, hpmcounter22

    # go to user mode
    li a0, 0
trap36:
    ecall

trap37:
    csrr t0, hpmcounter22

    #getting the mpp and mstatus Mpriv condition met
    #go to machine mode
    li a0, 3
trap38:
    ecall
    # set bit 17 of mstatus to enable STATUS_MPRV
    bseti t1, zero, 17
    csrs mstatus, t1

    li a0, 3
trap39:
    ecall

    # set bit 21 of mstatus to 0 to disable STATUS_TW
    csrr t1, mstatus
    bseti t2, zero, 21
    not t2, t2
    and t1, t1, t2
    csrs mstatus, t1

    # go to user mode
    li a0, 0
trap40:
    ecall

trap41:
    wfi



    # Test uncovered privdec instructions
    li a0, 3
trap42:
    ecall
    # exercise sfence.inval.ir instruction
    sfence.inval.ir

    # exercise sret with rs1 not 0
trap43:
    .word 0x102F8073

    # illegal ebreak with nonzero rs1
trap44:
    .word 0x00110073


    # cover mret when mpp = 3 and mprv = 1
    li a0, 3
trap45:
    ecall               # enter machine mode
    bseti t0, zero, 17
    csrs mstatus, t0    # set MPRV
    li t1, 0x00001800
    csrs mstatus, t1    # set MPP=3
    la t1, finished
    csrr t0, mepc
    csrw mepc, t1       # set mepc for mret to jump to
    mret


finished:
    # mret to M-mode leaves MPRV set and sets MPP to U, the least-privileged supported mode
    csrr a1, mstatus
    li a2, 0x21800          # MPRV | MPP
    and a1, a1, a2
    li a2, 0x20000          # MPRV = 1, MPP = U
    SC_CHECK_EQ a1, a2, 5
    CHECK_CSR stimecmp, -1, 6       # written from S-mode (CSR 333) once TM and STCE were both set

    jal check_traps
    SC_PASS
    j done

// Trap log: log_trap records mcause, mepc and mtval of every trap, then continues in the
// WALLY-init-lib.h handler, which handles ecalls and skips other faulting instructions.  check_traps
// compares the log with expected_traps, failing with index 0x100 + 3n + k for field k (0 = mcause,
// 1 = mepc, 2 = mtval) of trap n, or 0x1FF if the number of traps differs.
.equ TRAPLOG_MAX, 64
.align 4
log_trap:
    csrrw t0, mscratch, t0          # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    la t1, traplog
    ld t2, 0(t1)
    addi t2, t2, 1                  # count the trap
    sd t2, 0(t1)
    li t1, TRAPLOG_MAX
    bgtu t2, t1, 1f                 # log full: count only
    slli t3, t2, 4
    slli t2, t2, 3
    add t2, t2, t3
    la t1, traplog - 16
    add t1, t1, t2                  # trap n (from 1) goes at traplog + 24n - 16
    csrr t2, mcause
    sd t2, 0(t1)
    csrr t2, mepc
    sd t2, 8(t1)
    csrr t2, mtval
    sd t2, 16(t1)
1:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0          # restore t0 and the trap stack pointer
    j trap_handler

check_traps:
    la a1, traplog + 8
    la a2, expected_traps
    ld a3, 0(a2)
    addi a2, a2, 8
    slli a4, a3, 1
    add a3, a3, a4                  # fields to compare
    li a4, 0x100
1:  beqz a3, 2f
    ld a5, 0(a1)                    # actual
    ld a6, 0(a2)                    # expected
    bne a5, a6, 3f
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    addi a4, a4, 1
    j 1b
2:  la a1, traplog                  # and no extra traps
    ld a5, 0(a1)
    la a2, expected_traps
    ld a6, 0(a2)
    li a4, 0x1FF
    bne a5, a6, 3f
    ret
3:  la t0, selfcheck_record         # record the mismatch as SC_CHECK_EQ does
    li t1, 2
    sd t1, 0(t0)
    sd a4, 8(t0)
    sd zero, 16(t0)
    sd a6, 24(t0)
    sd a5, 32(t0)
    SC_REPORT_FAIL
    j done

.section .data
.align 3
traplog:                            # number of traps, then mcause, mepc and mtval of each
    .fill 1 + 3*TRAPLOG_MAX, 8, 0
expected_traps:                     # number of traps, then mcause, mepc and mtval of each
    .dword (2f - 1f) / 24
1:  .dword 8, trap01, 0                     # ecall from U: sret in M-mode returned to U (SPP = U)
    .dword 2, trap02, 0x10200073            # sret in U-mode
    .dword 2, trap03, 0x30200073            # mret in U-mode
    .dword 8, trap04, 0                     # ecall from U
    .dword 2, trap05, 0x14d31073            # stimecmp write from S with menvcfg.STCE = 0
    .dword 2, trap06, 0x14d022f3            # stimecmp read from S
    .dword 2, trap07, 0x3002a073            # mstatus write from S (so TVM stays 0)
    .dword 9, trap08, 0                     # ecall from S
    .dword 11, trap09, 0                    # ecall from M
    .dword 2, trap10, 0x14d01073            # stimecmp write from S, STCE = 0
    .dword 9, trap11, 0
    .dword 11, trap12, 0                    # no supervisor timer interrupt: mie.STIE = 0
    .dword 9, trap13, 0
    .dword 11, trap14, 0
    .dword 2, trap15, 0x14d01073            # stimecmp write from S, TM = 1 but STCE = 0
    .dword 9, trap16, 0
    .dword 11, trap17, 0
    .dword 2, trap18, 0x14d01073            # stimecmp write from S, STCE = 1 but TM = 0
    .dword 9, trap19, 0
    .dword 11, trap20, 0
    .dword 9, trap21, 0                     # (stimecmp write from S with TM = STCE = 1 is legal)
    .dword 11, trap22, 0
    .dword 9, trap23, 0                     # (S-mode CSR writes are legal)
    .dword 2, trap24, 0xb0129073            # CSR 0xB01 does not exist
    .dword 2, trap25, 0xb01022f3            # CSR 0xB01 read
    .dword 11, trap26, 0
    .dword 11, trap27, 0
    .dword 9, trap28, 0                     # (stimecmp write as CSR 333 from S is legal)
    .dword 8, trap29, 0                     # (hpmcounter22 read from U with mcounteren and scounteren set is legal)
    .dword 11, trap30, 0
    .dword 2, trap31, 0x12000073            # sfence.vma in U-mode
    .dword 8, trap32, 0
    .dword 9, trap33, 0                     # (sfence.vma in S-mode with TVM = 0 is legal)
    .dword 11, trap34, 0                    # (satp write in M-mode with TVM = 1 is legal)
    .dword 11, trap35, 0
    .dword 9, trap36, 0                     # (hpmcounter22 read from S with only mcounteren set is legal)
    .dword 2, trap37, 0xc16022f3            # hpmcounter22 read from U with scounteren clear
    .dword 8, trap38, 0
    .dword 11, trap39, 0
    .dword 11, trap40, 0
    .dword 2, trap41, 0x10500073            # wfi in U-mode times out
    .dword 8, trap42, 0
    .dword 2, trap43, 0x102f8073            # sret with rs1 != 0 (sfence.inval.ir before it is legal in M)
    .dword 2, trap44, 0x110073              # ebreak with rs1 != 0
    .dword 11, trap45, 0
2:
