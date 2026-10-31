///////////////////////////////////////////
// hpmcounters.S
//
// Written: david_harris@hmc.edu 27 October 2026
//
// Purpose: rv32imc hardware performance counter coverage (trl5 group D).  RV32 port of
//          tests/coverage64gc/hpmcounters.S restricted to the events rv32imc can produce (it has no
//          branch predictor, caches, fence.i, sfence.vma or FPU).  Runs a workload three times:
//          1. every event selector zero: no counter may change;
//          2. every selector nonzero and every counter inhibited: no counter may change;
//          3. every selector nonzero, nothing inhibited: each counter with a live event counts, and the
//             counters whose events cannot occur on rv32imc stay zero.
//          The 64-bit counters are written and read as low/high halves (mhpmcounterN/mhpmcounterNh).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define MTIME      0x0200BFF8
#define MTIMECMP   0x02004000
#define MCAUSE_MTI 0x80000007

#define HPM_ALL     3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
// events rv32imc produces: branch, jump, return, branch/jump taken (BPWrong, BPDirWrong, BTAWrong all
// equal PCSrcM without a predictor), class mismatch, load stall, store stall, CSR write, interrupt,
// exception, divider busy
#define HPM_LIVE    3,4,5,6,7,8,10,11,12,19,22,23,24
// events tied low on rv32imc: RAS (9), D$ (13-15), I$ (16-18), fence.i (20), sfence.vma (21), 25-31
#define HPM_DEAD    9,13,14,15,16,17,18,20,21,25,26,27,28,29,30,31

.macro SC_CHECK_GTU actual, bound, index
    bltu \bound, \actual, 9f
    la t0, selfcheck_record
    li t1, 2
    sw t1, 0(t0)
    li t1, \index
    sw t1, 4(t0)
    sw zero, 8(t0)
    sw \bound, 12(t0)
    sw \actual, 16(t0)
    SC_REPORT_FAIL
    j done
9:
.endm

.macro SET_ALL_EVENTS val
    li t0, \val
    .irp n, HPM_ALL
    csrw mhpmevent\n, t0
    .endr
.endm

#define COUNTER_LO(tag, n) (((tag) << 24) | 0x5A00 | (n))
#define COUNTER_HI(tag, n) (((tag) << 8) | (n))

.macro WRITE_COUNTERS tag
    .irp n, HPM_ALL
    li t0, COUNTER_LO(\tag, \n)
    csrw mhpmcounter\n, t0
    li t0, COUNTER_HI(\tag, \n)
    csrw (0xB80 + \n), t0
    .endr
.endm

.macro CHECK_COUNTERS tag, base
    .irp n, HPM_ALL
    li a1, COUNTER_LO(\tag, \n)
    csrr a0, mhpmcounter\n
    SC_CHECK_EQ a0, a1, \base + \n
    csrr a0, hpmcounter\n
    SC_CHECK_EQ a0, a1, \base + 32 + \n
    li a1, COUNTER_HI(\tag, \n)
    csrr a0, (0xB80 + \n)
    SC_CHECK_EQ a0, a1, \base + 64 + \n
    .endr
.endm

main:
    la t0, hpm_trap
    csrw mtvec, t0
    li s3, 0                    // interrupts taken (counted by hpm_trap)
    li s4, 0                    // exceptions taken (counted by hpm_trap)

    // 1. Every event selector zero, nothing inhibited: no counter may change.
    csrw mcountinhibit, zero
    SET_ALL_EVENTS 0
    WRITE_COUNTERS 1
    jal ra, workload
    CHECK_COUNTERS 1, 100

    // 2. Every selector nonzero, every counter inhibited: no counter may change.
    SET_ALL_EVENTS 1
    li t0, -1
    csrw mcountinhibit, t0
    WRITE_COUNTERS 2
    CHECK_COUNTERS 2, 200
    jal ra, workload
    CHECK_COUNTERS 2, 300

    // 3. Every selector nonzero, nothing inhibited: every live event counts, the dead ones do not.
    .irp n, HPM_ALL
    csrw mhpmcounter\n, zero
    csrw (0xB80 + \n), zero
    .endr
    csrw mcountinhibit, zero
    jal ra, workload
    li t0, -1
    csrw mcountinhibit, t0      // freeze the counters while they are checked
    .irp n, HPM_LIVE
    csrr a0, mhpmcounter\n
    SC_CHECK_GTU a0, zero, 400 + \n
    .endr
    .irp n, HPM_DEAD
    csrr a0, mhpmcounter\n
    SC_CHECK_EQ a0, zero, 450 + \n
    .endr

    // Each of the three workload passes takes exactly one interrupt and two exceptions.
    li a1, 3
    SC_CHECK_EQ s3, a1, 500
    li a1, 6
    SC_CHECK_EQ s4, a1, 501

    SC_PASS
    j done

workload:
    mv s1, ra                   // workload is called with jal, so save the return address

    // Branches (event 3), taken branches (6, 7, 8)
    li t2, 1
    beq  zero, zero, 1f         // taken
1:  bne  zero, zero, 1f         // not taken
1:  bltu zero, t2, 1f           // taken
1:  bgeu zero, t2, 1f           // not taken
1:
    // Jumps that are not returns (event 4) and returns (event 5)
    j 1f                        // jump
1:  jal ra, leaf                // call, and a return
    la t2, 1f
    jr t2                       // indirect jump through a non-link register
1:
    // jalr ra, 0(ra): the decode stage classes it as a return (rs1 = ra) but the fetch stage
    // predecoder does not (rd != x0), so the instruction class is wrong (event 10)
    la ra, 1f
    jalr ra, 0(ra)
1:
    // CSR writes (event 19)
    csrr t2, mscratch
    csrw mscratch, t2

    // Exceptions (event 23)
    csrr t2, 0xBFF              // no CSR at 0xBFF: illegal instruction
    li a0, 5
    ecall                       // the library handler ignores ecall 5

    // One machine timer interrupt (event 22): set mtimecmp a little past mtime and wait for hpm_trap
    mv s7, s3
    li t2, MTIME
    lw t3, 0(t2)
    lw t4, 4(t2)
    addi t5, t3, 64
    sltu t6, t5, t3
    add t4, t4, t6              // carry into the high word
    li t2, MTIMECMP
    li t6, -1
    sw t6, 4(t2)                // no early match while the low word is written
    sw t5, 0(t2)
    sw t4, 4(t2)
    li t3, 1000                 // give up eventually; the count check then fails
1:  bne s3, s7, 2f
    addi t3, t3, -1
    bnez t3, 1b
2:
    // A dependent load-use pair (load stall, event 11) and a load right after a store (event 12)
    la t2, scratch
    lw t4, 0(t2)
    add t5, t4, t4
    sw t5, 4(t2)
    lw t6, 4(t2)
    add t6, t6, t6

    // Divides (event 24)
    li t0, 1000
    li t1, 7
    div t2, t0, t1
    remu t3, t0, t1

    mv ra, s1
    ret

leaf:
    ret

.align 4
hpm_trap:
    csrrw tp, mscratch, tp      // tp = trap stack pointer, as in the library handler
    sw t0, 0(tp)
    csrr t0, mcause
    bltz t0, hpm_interrupt
    addi s4, s4, 1
    lw t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler
hpm_interrupt:
    sw t1, -4(tp)
    li t1, MCAUSE_MTI
    bne t0, t1, hpm_bad_interrupt
    li t0, -1
    li t1, MTIMECMP
    sw t0, 4(t1)                // no further timer interrupt
    sw t0, 0(t1)
    addi s3, s3, 1
    lw t1, -4(tp)
    lw t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
hpm_bad_interrupt:
    SC_FAIL 0xF1                // an interrupt other than the machine timer

.section .data
.align 3
scratch:
    .fill 4, 4, 0
