///////////////////////////////////////////
// hpmcounters.S
//
// Written: david_harris@hmc.edu 27 October 2026
//
// Purpose: rv32imc hardware performance counter coverage (trl5 group D).  rv32imc has COUNTERS = 7:
//          mcycle, time, minstret and mhpmcounter3-6, which count branches (event 3), jumps that are not
//          returns (4), returns (5) and branch mispredictions (6; without a branch predictor, every taken
//          branch or jump).  The test
//          1. runs a workload with every event selector zero: no counter may change;
//          2. runs it with every selector nonzero and every counter inhibited: no counter may change, and
//             mcycle and minstret hold the values written to them;
//          3. runs it with every selector nonzero and nothing inhibited: each of counters 3-6 counts;
//          4. checks the absent counters 7-31: mhpmevent7-31, mhpmcounter7-31 and mhpmcounter7-31h are
//             read-only zero (writes are ignored), hpmcounter7-31 and hpmcounter7-31h read zero in M mode,
//             and every hpmcounter/hpmcounterh write is an illegal instruction (they are read-only);
//          5. checks that mcountinhibit and mcounteren keep only the bits of implemented counters, and that
//             U mode may read hpmcounter3 but not hpmcounter7 (its mcounteren bit is read-only zero).
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

// implemented hardware performance counters (COUNTERS = 7) and the absent ones, which read zero
#define HPM_IMPL    3,4,5,6
#define HPM_ABSENT  7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
#define ALL_32      0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
#define MCOUNTINHIBIT_IMPL 0x7D     // CY, IR, HPM3-6; TM (bit 1) is read-only zero
#define MCOUNTEREN_IMPL    0x7F     // CY, TM, IR, HPM3-6

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

.macro SET_EVENTS val
    li t0, \val
    .irp n, HPM_IMPL
    csrw mhpmevent\n, t0
    .endr
.endm

#define COUNTER_LO(tag, n) (((tag) << 24) | 0x5A00 | (n))
#define COUNTER_HI(tag, n) (((tag) << 8) | (n))

// Write mhpmcounterN and mhpmcounterNh for each N in the list
.macro WRITE_COUNTERS tag, list:vararg
    .irp n, \list
    li t0, COUNTER_LO(\tag, \n)
    csrw (0xB00 + \n), t0
    li t0, COUNTER_HI(\tag, \n)
    csrw (0xB80 + \n), t0
    .endr
.endm

// Check each counter through all four names: mhpmcounterN, hpmcounterN, mhpmcounterNh, hpmcounterNh
.macro CHECK_COUNTERS tag, base, list:vararg
    .irp n, \list
    li a1, COUNTER_LO(\tag, \n)
    csrr a0, (0xB00 + \n)
    SC_CHECK_EQ a0, a1, \base + \n
    csrr a0, (0xC00 + \n)
    SC_CHECK_EQ a0, a1, \base + 32 + \n
    li a1, COUNTER_HI(\tag, \n)
    csrr a0, (0xB80 + \n)
    SC_CHECK_EQ a0, a1, \base + 64 + \n
    csrr a0, (0xC80 + \n)
    SC_CHECK_EQ a0, a1, \base + 96 + \n
    .endr
.endm

main:
    la t0, hpm_trap
    csrw mtvec, t0
    li s3, 0                    // interrupts taken (counted by hpm_trap)
    li s4, 0                    // exceptions taken (counted by hpm_trap)

    // 1. Every event selector zero, nothing inhibited: no counter may change.
    csrw mcountinhibit, zero
    SET_EVENTS 0
    WRITE_COUNTERS 1, HPM_IMPL
    jal ra, workload
    CHECK_COUNTERS 1, 1000, HPM_IMPL

    // 2. Every selector nonzero, every counter inhibited: no counter may change, mcycle and minstret included.
    SET_EVENTS 1
    li t0, -1
    csrw mcountinhibit, t0
    WRITE_COUNTERS 2, 0, 2, HPM_IMPL
    CHECK_COUNTERS 2, 2000, 0, 2, HPM_IMPL
    jal ra, workload
    CHECK_COUNTERS 2, 3000, 0, 2, HPM_IMPL

    // 3. Every selector nonzero, nothing inhibited: every counter counts its event.
    .irp n, HPM_IMPL
    csrw (0xB00 + \n), zero
    csrw (0xB80 + \n), zero
    .endr
    csrw mcountinhibit, zero
    jal ra, workload
    li t0, -1
    csrw mcountinhibit, t0      // freeze the counters while they are checked
    .irp n, HPM_IMPL
    csrr a0, (0xB00 + \n)
    SC_CHECK_GTU a0, zero, 4000 + \n
    .endr

    // Each of the three workload passes takes exactly one interrupt and two exceptions.
    li a1, 3
    SC_CHECK_EQ s3, a1, 4100
    li a1, 6
    SC_CHECK_EQ s4, a1, 4101

    // 4. Absent counters 7-31.  Their event selectors and machine counters are read-only zero: a write is
    // legal and ignored.  In M mode their user counters read zero.
    li s4, 0
    li a1, 0
    .irp n, HPM_ABSENT
    li t0, -1
    csrw (0x323 + \n - 3), t0  // mhpmevent\n
    csrr a0, (0x323 + \n - 3)
    SC_CHECK_EQ a0, a1, 5000 + \n
    li t0, COUNTER_LO(4, \n)
    csrw (0xB00 + \n), t0      // mhpmcounter\n
    li t0, COUNTER_HI(4, \n)
    csrw (0xB80 + \n), t0      // mhpmcounter\nh
    csrr a0, (0xB00 + \n)
    SC_CHECK_EQ a0, a1, 5032 + \n
    csrr a0, (0xC00 + \n)
    SC_CHECK_EQ a0, a1, 5064 + \n
    csrr a0, (0xB80 + \n)
    SC_CHECK_EQ a0, a1, 5096 + \n
    csrr a0, (0xC80 + \n)
    SC_CHECK_EQ a0, a1, 5128 + \n
    .endr
    SC_CHECK_EQ s4, a1, 5200    // none of these accesses traps

    // Every user counter (cycle, time, instret, hpmcounter3-31 and their high halves) is read-only, so a
    // write is an illegal instruction, whether or not the counter exists.
    .irp n, ALL_32
    csrw (0xC00 + \n), zero
    csrw (0xC80 + \n), zero
    .endr
    li a1, 64
    SC_CHECK_EQ s4, a1, 5201

    // 5. mcountinhibit and mcounteren keep only the bits of implemented counters.
    li t0, -1
    csrw mcountinhibit, t0
    csrr a0, mcountinhibit
    li a1, MCOUNTINHIBIT_IMPL
    SC_CHECK_EQ a0, a1, 6000
    csrw mcounteren, t0
    csrr a0, mcounteren
    li a1, MCOUNTEREN_IMPL
    SC_CHECK_EQ a0, a1, 6001

    // In U mode, with every mcounteren bit set, hpmcounter3 is readable but hpmcounter7 is not.
    li s4, 0
    li s5, 0x1234
    li s6, 0x1234
    li a0, 0
    ecall                       // switch to U mode
    csrr s5, hpmcounter3        // legal: overwrites s5 with the frozen count (nonzero from part 3)
    csrr s6, hpmcounter7        // illegal: mcounteren[7] is read-only zero, so s6 keeps 0x1234
    li a0, 3
    ecall                       // back to M mode
    li t2, 3                    // two ecalls and the illegal hpmcounter7 read
    SC_CHECK_EQ s4, t2, 6002
    li a1, 0x1234
    SC_CHECK_EQ s6, a1, 6003
    csrr a1, mhpmcounter3
    SC_CHECK_EQ s5, a1, 6004

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
