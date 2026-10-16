///////////////////////////////////////////
// hpmcounters.S
//
// Written: David_Harris@hmc.edu 18 September 2026
//
// Purpose: Exercise and check the hardware performance monitor counters in csrc.sv.
//
//          Counters 3 and above only increment when their event selector is nonzero
//          (CounterInc[i] = CounterEvent[i] & ~MCOUNTINHIBIT_REGW[i] & (MHPMEVENT_REGW[i] != 0)),
//          so nothing in that expression is exercised until a test writes mhpmevent.  This test
//          runs a workload that generates every event csrc.sv counts, including one machine timer
//          interrupt, three times, and checks each term of CounterInc:
//            1. every mhpmevent = 0: no mhpmcounter changes
//            2. every counter inhibited: no counter changes, including mcycle and minstret, and a
//               value written to an mhpmcounter reads back exactly through mhpmcounter and hpmcounter
//            3. every mhpmevent nonzero and nothing inhibited: each counter with an event source
//               counts, counters 25-31 (no event source) stay 0, and the events that are a property
//               of retired instructions count exactly over straight-line blocks in the workload.
//          ImperasDV does not model the counters (the testbench marks them volatile), so lockstep
//          cannot check them; these checks are the only thing that does.
//
//          Failure index in selfcheck_record: 100 + n (1), 200 + n and 300 + n (2, before and after
//          the workload; + 50 for the hpmcounter alias), 400 + n (3), 500 + slot (3, exact counts,
//          see CHECK_DELTA), 600-607 (mcycle, minstret, time and the trap counts), 0xF1 (an
//          interrupt other than the machine timer).
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
////////////////////////////////////////////////////////////////////////////////////////////////

// load code to initialize stack, handle interrupts, terminate
#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

#define MTIME    0x0200BFF8
#define MTIMECMP 0x02004000
#define MCAUSE_MTI 0x8000000000000007

// Counters with an event selector (rv64gc implements all 32)
#define HPM_ALL     3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
#define HPM_EVENT   3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24
#define HPM_NOEVENT 25,26,27,28,29,30,31

// SC_CHECK_GTU actual, bound, index: fail the test (status 2) unless actual > bound, unsigned.
.macro SC_CHECK_GTU actual, bound, index
    bltu \bound, \actual, 9f
    la t0, selfcheck_record
    li t1, 2
    sd t1, 0(t0)
    li t1, \index
    sd t1, 8(t0)
    sd zero, 16(t0)
    sd \bound, 24(t0)
    sd \actual, 32(t0)
    SC_REPORT_FAIL
    j done
9:
.endm

// Write val to every mhpmevent, including the ones whose event source is tied to zero, so that
// the (MHPMEVENT_REGW[i] != 0) term is exercised for every counter index.
.macro SET_ALL_EVENTS val
    li t0, \val
    .irp n, HPM_ALL
    csrw mhpmevent\n, t0
    .endr
.endm

// Distinct value for counter n in phase tag, so a write to the wrong counter is caught too.
#define COUNTER_VAL(tag, n) (((tag) << 40) | ((n) << 32) | 0x5A00 | (n))

// Write every mhpmcounter, so WriteHPMCOUNTERM[i] is asserted for each counter index in turn.
.macro WRITE_COUNTERS tag
    .irp n, HPM_ALL
    li t0, COUNTER_VAL(\tag, \n)
    csrw mhpmcounter\n, t0
    .endr
.endm

// Check that every counter still holds what WRITE_COUNTERS tag wrote, reading it both as
// mhpmcounter (index base + n) and as its hpmcounter alias (index base + 50 + n).
.macro CHECK_COUNTERS tag, base
    .irp n, HPM_ALL
    li a1, COUNTER_VAL(\tag, \n)
    csrr a0, mhpmcounter\n
    SC_CHECK_EQ a0, a1, \base + \n
    csrr a0, hpmcounter\n
    SC_CHECK_EQ a0, a1, \base + 50 + \n
    .endr
.endm

// deltas[slot] = t1 - start.  The exact-count blocks in the workload record their counts here.
.macro RECORD start, slot
    sub t1, t1, \start
    la t0, deltas
    sd t1, 8*\slot(t0)
.endm

// Fail (index 500 + slot) unless the workload's last pass recorded expected in deltas[slot].
.macro CHECK_DELTA slot, expected
    la a2, deltas
    ld a0, 8*\slot(a2)
    li a1, \expected
    SC_CHECK_EQ a0, a1, 500 + \slot
.endm

main:
    la t0, hpm_trap
    csrw mtvec, t0
    li s3, 0                    // interrupts taken (counted by hpm_trap)
    li s4, 0                    // exceptions taken (counted by hpm_trap)
    li t0, 1 << 13
    csrs mstatus, t0            // mstatus.FS = Initial, so the workload can divide in the FPU

    // 1. Every event selector zero, nothing inhibited: CounterInc's (MHPMEVENT_REGW[i] != 0) term
    //    is false while the events toggle, so no counter may change.
    csrw mcountinhibit, zero
    SET_ALL_EVENTS 0
    WRITE_COUNTERS 1
    jal ra, workload
    CHECK_COUNTERS 1, 100

    // 2. Every selector nonzero, every counter inhibited: the ~MCOUNTINHIBIT_REGW[i] term is false,
    //    so no counter may change.  A value written to an inhibited counter must read back exactly.
    SET_ALL_EVENTS 1
    li t0, -1
    csrw mcountinhibit, t0
    WRITE_COUNTERS 2
    CHECK_COUNTERS 2, 200
    csrr s8, mcycle
    csrr s9, minstret
    jal ra, workload
    CHECK_COUNTERS 2, 300
    csrr a0, mcycle
    SC_CHECK_EQ a0, s8, 600
    csrr a0, cycle
    SC_CHECK_EQ a0, s8, 601
    csrr a0, minstret
    SC_CHECK_EQ a0, s9, 602
    csrr a0, instret
    SC_CHECK_EQ a0, s9, 603

    // 3. Every selector nonzero, nothing inhibited: every counter with an event source counts.
    .irp n, HPM_ALL
    csrw mhpmcounter\n, zero
    .endr
    csrw mcountinhibit, zero
    jal ra, workload
    li t0, -1
    csrw mcountinhibit, t0      // freeze the counters while they are checked
    .irp n, HPM_EVENT
    csrr a0, mhpmcounter\n
    SC_CHECK_GTU a0, zero, 400 + \n
    .endr
    .irp n, HPM_NOEVENT         // CounterEvent[31:25] is tied low
    csrr a0, mhpmcounter\n
    SC_CHECK_EQ a0, zero, 400 + \n
    .endr

    // Exact counts over the workload's straight-line blocks
    CHECK_DELTA 0, 4            // branches: 2 taken, 2 not taken
    CHECK_DELTA 1, 4            // jumps that are not returns: j, 2 calls, jr through a non-link register
    CHECK_DELTA 2, 2            // returns
    CHECK_DELTA 3, 5            // CSR writes; the csrrs/csrrci forms that only read are not counted
    CHECK_DELTA 4, 2            // fence.i; an ordinary fence is not counted
    CHECK_DELTA 5, 2            // sfence.vma
    CHECK_DELTA 6, 3            // exceptions: 2 illegal instructions and an ecall
    CHECK_DELTA 7, 0            //   interrupts counted during the exceptions
    CHECK_DELTA 8, 3            //   exceptions hpm_trap saw
    CHECK_DELTA 9, 1            // interrupts: one machine timer interrupt
    CHECK_DELTA 10, 0           //   exceptions counted during the interrupt
    CHECK_DELTA 11, 1           //   interrupts hpm_trap saw

    // Each of the three workload passes takes exactly one interrupt and three exceptions.
    li a1, 3
    SC_CHECK_EQ s3, a1, 604
    li a1, 9
    SC_CHECK_EQ s4, a1, 605

    // The unprivileged shadows of the first three counters are read-only; read them too.  time
    // shadows the CLINT's mtime, which keeps counting, so a later read of mtime is larger.
    csrr t2, cycle
    csrr t2, instret
    csrr a0, time
    SC_CHECK_GTU a0, zero, 606
    li t2, MTIME
    ld a1, 0(t2)
    SC_CHECK_GTU a1, a0, 607

    SC_PASS
    j done

// Generate each event csrc.sv counts: branches, jumps and returns, mispredictions of direction,
// target, return address and instruction class, load and store stalls, data and instruction cache
// accesses, misses and stall cycles, CSR writes, fence.i, sfence.vma, an interrupt, exceptions
// and divides.  The events that are a property of the instructions retired are counted exactly
// over straight-line blocks, recorded in deltas[] for main to check after the counted pass.
// Uses t0-t6, a0, s1 and s5-s7.
workload:
    mv s1, ra                   // workload is called with jal, so save the return address

    // Branches (event 3)
    li t2, 1
    csrr s5, mhpmcounter3
    beq  zero, zero, 1f         // taken
1:  bne  zero, zero, 1f         // not taken
1:  bltu zero, t2, 1f           // taken
1:  bgeu zero, t2, 1f           // not taken
1:  csrr t1, mhpmcounter3
    RECORD s5, 0

    // Jumps that are not returns (event 4) and returns (event 5)
    csrr s5, mhpmcounter4
    csrr s6, mhpmcounter5
    j 1f                        // jump
1:  jal ra, leaf                // call, and a return
    jal ra, leaf                // call, and a return
    la t2, 1f
    jr t2                       // indirect jump through t2 (x7), which is not a link register
1:  csrr t1, mhpmcounter4
    RECORD s5, 1
    csrr t1, mhpmcounter5
    RECORD s6, 2

    // CSR writes (event 19)
    csrr s5, mhpmcounter19
    csrr t2, mscratch           // read only
    csrw mscratch, t2           // write (the trap stack pointer, unchanged)
    csrw sscratch, t2           // write
    csrrs t3, sscratch, zero    // csrrs with rs1 = x0 only reads
    csrs sscratch, t2           // csrrs with rs1 != x0 writes
    csrrci t3, sscratch, 0      // csrrci with uimm = 0 only reads
    csrwi sscratch, 0           // csrrwi writes even with uimm = 0
    csrc sscratch, t2           // csrrc with rs1 != x0 writes
    csrr t1, mhpmcounter19
    RECORD s5, 3

    // Instruction cache invalidate (event 20), so later fetches miss in the I$
    csrr s5, mhpmcounter20
    fence.i
    fence                       // an ordinary fence does not invalidate the I$
    fence.i
    csrr t1, mhpmcounter20
    RECORD s5, 4

    // TLB flush (event 21)
    csrr s5, mhpmcounter21
    sfence.vma
    sfence.vma t2, zero
    csrr t1, mhpmcounter21
    RECORD s5, 5

    // Exceptions (event 23).  hpm_trap passes them to the WALLY-init-lib.h handler, which skips
    // the faulting instruction and ignores ecalls other than 0-4.
    csrr s5, mhpmcounter23
    csrr s6, mhpmcounter22
    mv s7, s4
    csrr t2, 0xBFF              // no CSR at 0xBFF: illegal instruction
    li a0, 5
    ecall
    csrr t2, 0xBFF
    csrr t1, mhpmcounter23
    RECORD s5, 6
    csrr t1, mhpmcounter22
    RECORD s6, 7
    mv t1, s4
    RECORD s7, 8

    // One machine timer interrupt (event 22): set mtimecmp a little past mtime and wait for
    // hpm_trap to take it.  hpm_trap sets mtimecmp back to the maximum so it is not retaken.
    csrr s5, mhpmcounter22
    csrr s6, mhpmcounter23
    mv s7, s3
    li t2, MTIME
    ld t3, 0(t2)
    addi t3, t3, 64
    li t2, MTIMECMP
    sd t3, 0(t2)
    li t3, 1000                 // give up eventually; the count check below then fails
1:  bne s3, s7, 2f
    addi t3, t3, -1
    bnez t3, 1b
2:  nop                         // room for a second interrupt to show up if one were taken
    nop
    csrr t1, mhpmcounter22
    RECORD s5, 9
    csrr t1, mhpmcounter23
    RECORD s6, 10
    mv t1, s3
    RECORD s7, 11

    // Branches, both directions, and a loop whose final branch mispredicts.
    li t0, 16
1:  addi t0, t0, -1
    andi t1, t0, 1
    beqz t1, 2f                 // alternates taken and not taken
    nop
2:  bnez t0, 1b                 // loop back edge, mispredicts on the last iteration

    // A loop long enough that its exit cannot be predicted from the global history, so the exit
    // mispredicts its direction on every pass (event 7).
    li t2, 32
1:  addi t2, t2, -1
    bnez t2, 1b

    // An indirect jump that alternates between two targets, so the BTB's target is wrong (event 8).
    li t3, 4
    la t2, ijmp_a
ijmp:
    jr t2
ijmp_a:
    la t2, ijmp_b
    j ijmp_next
ijmp_b:
    la t2, ijmp_a
ijmp_next:
    addi t3, t3, -1
    bnez t3, ijmp

    // A return to somewhere other than the instruction after its call, so the RAS is wrong (event 9).
    jal ra, ras_mismatch
    nop                         // the RAS predicts this; ras_mismatch returns past it
ras_resume:

    // alias_a and alias_b share a BTB entry, and each overwrites it with its own instruction
    // class, so the class prediction is wrong on every pass (event 10).
    jal ra, alias_a
    jal ra, alias_b

    // Jumps and returns, exercising the return address stack.
    jal ra, leaf
    jal ra, leaf

    // Loads and stores.  Each line is flushed first so the store misses in the D$, and the stride
    // is larger than a cache line, producing data cache accesses, misses and stall cycles.
    la t2, scratch
    li t3, 8
3:  cbo.flush (t2)
    sd t3, 0(t2)
    ld t4, 0(t2)
    addi t2, t2, 128            // skip a cache line each time
    addi t3, t3, -1
    bnez t3, 3b

    // A dependent load-use pair (load stall, event 11) and a load right after a store (store
    // stall, event 12).
    la t2, scratch
    ld t4, 0(t2)
    add t5, t4, t4              // uses the loaded value immediately
    sd t5, 8(t2)
    ld t6, 8(t2)
    add t6, t6, t6

    // Divides, for the divider busy event (24).  rv64gc divides integers in the FPU's divider.
    li t0, 1000
    li t1, 7
    div t2, t0, t1
    remu t3, t0, t1
    fcvt.d.l ft0, t0
    fcvt.d.l ft1, t1
    fdiv.d ft2, ft0, ft1

    mv ra, s1
    ret

leaf:
    ret

ras_mismatch:
    la ra, ras_resume
    ret

// Trap handler: counts each machine timer interrupt in s3, sets mtimecmp back to the maximum and
// returns to the interrupted instruction.  Exceptions are counted in s4 and passed to the
// WALLY-init-lib.h handler; it would skip the interrupted instruction if given an interrupt.
.align 4
hpm_trap:
    csrrw tp, mscratch, tp      // tp = trap stack pointer, as in the library handler
    sd t0, 0(tp)
    csrr t0, mcause
    bltz t0, hpm_interrupt
    addi s4, s4, 1
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    j trap_handler
hpm_interrupt:
    sd t1, -8(tp)
    li t1, MCAUSE_MTI
    bne t0, t1, hpm_bad_interrupt
    li t0, -1
    li t1, MTIMECMP
    sd t0, 0(t1)                // no further timer interrupt
    addi s3, s3, 1
    ld t1, -8(tp)
    ld t0, 0(tp)
    csrrw tp, mscratch, tp
    mret
hpm_bad_interrupt:
    SC_FAIL 0xF1                // an interrupt other than the machine timer

// Two routines exactly 4 KiB apart, so their first instructions share a BTB entry (the BTB is
// indexed by {PC[11] ^ PC[1], PC[10:2]} with no tag).  One is a jump and the other is not.
.align 12
alias_a:
    j 1f
1:  ret
.align 12
alias_b:
    nop
    ret

.section .data
.align 3
deltas:
    .fill 12, 8, 0
.align 12
scratch:
    .fill 256, 8, 0
